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
    uniform uint32 buy;
    uniform uint32 sell;
    uniform uint32 qty;
};

/** 
 * Full table containing aggregates of all products.
 */
export static uniform Aggregate table[32768];

/**
 * Parses an integer terminated by a comma. Advances the cursor past the comma. 
 */
static inline uniform int parse_int(uniform uint8 data[], uniform int * uniform cursor) {
    uniform int result = 0;
    uniform int num_len = 0;

    do {
        result *= 10;
        result += (data[*cursor] - 48);
        *cursor += 1;
    } while(data[*cursor] != 44);

    *cursor += 1;
    return result;
}

/**
 * Returns the position of a comma within data[offset...offset + 8]. Assumes a
 * comma always exists.
 */
static inline uniform int get_comma_loc_8(uniform uint8 data[], uniform int offset) {
    int pos = 0;
    foreach(j = 0 ... 8) {
        if(data[offset + j] == 44) pos = j;
    }
    return reduce_add(pos);
}

/**
 * Skips to the end of the line, and returns the index of the `\n` (or `\0`). 
 * Routine reads past the end of the array by `programCount` bytes.
 */
static inline uniform int skip_to_eol(uniform uint8 data[], uniform int index) {
    bool found = false;
    do {
        foreach(j = 0 ... programCount) {
            if (data[index + j] == 10) { found = true; } // Newline
            if (data[index + j] == 0) { found = true; }  // EOF
        }
        index += programCount;
    } while (!any(found));

    /* now we know the newline is in [index - programCount ... index] */
    uniform int base = index - programCount;
    int match = 0;
    foreach(j = 0 ... programCount) {
        if (data[base + j] == 10) match = j;
    }
    return base + reduce_add(match);
}

/**
 * Processes a CSV file and stores aggregate results in the static [`table`].
 */
export uniform Aggregate* uniform process_csv(
    uniform uint8 data[], 
    uniform int count
) {
    uniform int cursor = 0;
    uniform int line_no = 0;

    do {

        /* skip title row */
        cursor = skip_to_eol(data, cursor) + 1;
        line_no++;

        /* check for EOF */
        if (cursor >= count) { break; }
        
        /* compute offset to source column */
        uniform int record_no = get_comma_loc_8(data, cursor);
        cursor += record_no + 43;

        /* check if this is a ToClnt row */
        uniform uint8 to_clnt[6] = { 84, 111, 67, 108, 110, 116 };
        uniform bool wrong_row = false;
        foreach (j = 0 ... 6) {
            if (data[cursor + j] != to_clnt[j]) wrong_row = true;
        }

        /* skip row if not ToClnt */
        if(any(wrong_row)) {
            continue;
        }

        /* skip to the end of the Buy/Sell column (36 chars away from ToClnt). 
         * This lands at either the `,` of `Sell,`, or the first digit in the 
         * OrdQty column.
         * 
         * Change,Sell,141,141,0,
         * Change,Buy,293,293,293
         *            ^
         *     move cursor here
         */
        cursor += 36;
        uniform bool sell = data[cursor] == 44; /* check for `,` */

        /* move cursor to first digit in OrdQt if it's currently on a comma */
        if (sell) cursor += 1;

        /* parse and max all three quantities */
        uniform int ord_qty = parse_int(data, &cursor);
        uniform int wrk_qty = parse_int(data, &cursor);
        uniform int exc_qty = parse_int(data, &cursor);

        uniform int max_qty = ord_qty > wrk_qty ? ord_qty : wrk_qty;
        max_qty = exc_qty > max_qty ? exc_qty : max_qty;

        /* parse product symbol */
        uniform uint16 product = (data[cursor] - 65) << 10;
        product += (data[cursor + 1] - 65) << 5;
        product += data[cursor + 2] - 65;

        
        /* fill data */
        table[product].qty += max_qty;
        if (sell) table[product].sell++;
        else      table[product].buy++;

    } while(cursor < count);

    return table;
}

