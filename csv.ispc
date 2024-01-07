/*
 * Copyright (c) Adrian Alic <contact@alic.dev>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

/** 
 * Aggregated data of a single product
 */
export struct Aggregate {
    uniform uint32 qty;
    uniform uint16 buy;
    uniform uint16 sell;
};

/** 
 * Full table containing aggregates of all products.
 */
export static uniform Aggregate table[32768];

/**
 * Parses an integer terminated by a comma. Advances the cursor past the comma. 
 */
static inline uniform int uniform parse_int(uniform uint8** uniform data) {
    uniform int result = 0;
    uniform int num_len = 0;

    do {
        result *= 10;
        result += ((*data)[0] - 48);
        *data += 1;
    } while((*data)[0] != 44);

    *data += 1;
    return result;
}

/**
 * Returns the position of a comma within data[offset...offset + 10]. Assumes a
 * comma always exists.
 */
#if (TARGET_WIDTH < 32)
#error Target width must be at least 32 for this code. Examples: avx-i8x32
#endif
static inline uniform uint8* uniform get_comma_loc_10(uniform uint8 data[]) {
    /* de mask off all bits higher than 10 */
    uniform int packed = packmask(data[programIndex] == 44) & 0x3ff;
    return data +  count_trailing_zeros(packed);
}
static inline uniform uint8* uniform skip_commas_2(uniform uint8 data[]) {
    uniform uint packed = (uint)packmask(data[programIndex] == 44);
    /* unset least significant set bit */
    uniform uint first = count_trailing_zeros(packed);
    packed &= ~(1 << first);
    return data + count_trailing_zeros(packed);
}
static inline uniform uint8* uniform skip_commas_4(uniform uint8 data[]) {
    uniform uint packed = (uint)packmask(data[programIndex] == 44);

    /* unset 3 least significant set bits */
    for(uniform int i = 0; i < 3; i++) {
        packed &= ~((uint)1 << count_trailing_zeros(packed));
    }
    return data + count_trailing_zeros(packed);
}

/**
 * Skips to the end of the line, and returns the index of the `\n` (or `\0`). 
 * Routine reads past the end of the array by `programCount` bytes.
 */
static inline uniform uint8* uniform skip_to_eol(uniform uint8 data[]) {
    /* avoid cache-line splits */
    data = (uniform uint8* uniform)((uint64)data & ~(programCount - 1));
    bool found1, found2;
    do {
        prefetch_nt(data + 0xa0);
        found1 = streaming_load(data) == 10;
        found2 = streaming_load(data + programCount) == 10;
        data += programCount * 2;
    } while (!any(found1 || found2));

    uniform int pack1 = packmask(found1);
    uniform int pack2 = packmask(found2);
    uniform int lz1 = count_trailing_zeros(pack1);
    uniform int lz2 = count_trailing_zeros(pack2) % programCount;

    return data - programCount * 2 + lz1 + lz2;
}

static const uniform uint8 to_clnt[32] = { 84, 111, 67, 108, 110, 116,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
};

/**
 * Processes a CSV file and stores aggregate results in the static [`table`].
 */
export uniform Aggregate* uniform process_csv(
    uniform uint8 data[], 
    uniform uint64 count
) {
    uniform uint64 limit = (uint64)data + (uint64)count;
    /* We can skip the title row, so start directly into loop */
    do {
        data = skip_to_eol(data) + 1;

        /* Break if we're at the EOF */
        if ((uint64)data  >= limit || data[0] == 0) break;

        /* Skip record number (i.e. first column) and comma */
        data = get_comma_loc_10(data);

        /* Skip ISO8601 timestamp + comma */
        data += 24 + 1;

        /* Find position of second comma. We assume that the exchange identifier and
         * srskey are together not longer than 29 characters. */
        data = skip_commas_2(data) + 1;

        /* Check if this is a ToClnt row */
        bool wrong_row = data[programIndex] != to_clnt[programIndex];
        wrong_row &= programIndex < 6;
        
        /* Skip row if not ToClnt */
        if(any(wrong_row)) {
            /* It's safe to skip at least 35 characters, because there are 35 columns
             * after `Source`. So even if the columns are empty, there will be at least
             * 35 commas after the current position. */
            data += 35;
            continue;
        };

        /* Skip over ToClnt */
        data += 7;

        /* Skip to the start of the Buy/Sell column (5 columns away from ToClnt). 
         * 
         * Change,Sell,141,141,0,
         * Change,Buy,293,293,293
         *        ^
         *   move cursor here
         */
        data = skip_commas_4(data) + 1;
        uniform bool sell = data[0] == 83; /* check for `S` */

        /* Skip over Buy/Sell column */
        data += sell ? 5 : 4;

        /* Parse and max all three quantities */
        uniform int ord_qty = parse_int(&data);
        uniform int wrk_qty = parse_int(&data);
        uniform int exc_qty = parse_int(&data);

        uniform int max_qty = ord_qty > wrk_qty ? ord_qty : wrk_qty;
        max_qty = exc_qty > max_qty ? exc_qty : max_qty;

        /* Parse product symbol */
        uniform uint16 product = ((uint16)data[0] - 65) << 10;
        product += ((uint16)data[1] - 65) << 5;
        product += data[2] - 65;

        /* Fill data */
        table[product].qty += max_qty;
        if (sell) table[product].sell++;
        else      table[product].buy++;

        /* It's safe to skip at least 26 characters, because there are 26 columns
         * after `Prod`. So even if the columns are empty, there will be at least
         * 26 commas after the current position. */
        data += 26;

    } while((uint64)data < limit);

    return table;
}

