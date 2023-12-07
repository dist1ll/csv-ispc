#include "csv_ispc.h"
#include <_types/_uint8_t.h>
#include <cassert>
#include <cstdio>
#include <cstdlib>
#include <stdio.h>
#include <string.h>

void process(FILE *f) {
  auto buflen = 2 << 26;
  // auto buflen = 1 << 15;
  auto buf = (uint8_t *)malloc(buflen + 4096);

  ispc::Aggregate* table;
  int rdlen = 0;

  while(true) {
    rdlen = fread(buf, 1, buflen, f);
    if (rdlen <= 0) break;
    table = ispc::process_csv(buf, buflen);
    printf("read: %d\n", rdlen);
  }

  // for (int i = 0; i < 32768; i++) {
  //   if (table[i].buy == 0)
  //     continue;
  //   char c1 = (i >> 10) + 65;
  //   char c2 = ((i >> 5) & 0b11111) + 65;
  //   char c3 = (i & 0b11111) + 65;
  //   int cnt = table[i].buy + table[i].sell;
  //   printf("%c%c%c cnt=%4d buy=%4d sell=%4d avg qty=%6.2f\n", 
  //     c1, c2, c3, 
  //     cnt, table[i].buy, table[i].sell, (double)table[i].qty/cnt);
  // }


  free(buf);
}

int main(int argc, char *argv[]) {
  if (argc != 2) {
    printf("Error: expected path to csv file.\nUsage: csv <PATH>\n");
    std::exit(1);
  }
  FILE *f = fopen(argv[1], "rb");
  if (f == NULL) {
    printf("Error opening file.\n");
    std::exit(1);
  }
  process(f);
  fclose(f);
}
