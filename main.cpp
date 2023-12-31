#include "csv_ispc.h"
#include <cstdio>
#include <cstdlib>
#include <sys/mman.h>
#include <sys/stat.h>

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

  int fd = fileno(f);
  struct stat st;
  fstat(fd, &st);

  /* File size increased by 8KiB (or 12KiB if already 4KiB aligned) */
  long long map_size = st.st_size;
  if ((st.st_size & 0xfff) != 0) {
    map_size = (st.st_size + 0x2000) & (~0xfff);
  }


  uint8_t *addr =
      (uint8_t *)mmap(NULL, map_size, PROT_READ, MAP_PRIVATE, fd, 0);
  ispc::Aggregate *table = ispc::process_csv(addr, st.st_size);
  munmap((void *)addr, map_size);
  fclose(f);

  /* Print results */
  for (int i = 0; i < 32768; i++) {
    if (table[i].buy == 0)
      continue;
    char c1 = (i >> 10) + 65;
    char c2 = ((i >> 5) & 0b11111) + 65;
    char c3 = (i & 0b11111) + 65;
    int cnt = table[i].buy + table[i].sell;
    printf("%c%c%c cnt=%4d buy=%4d sell=%4d avg qty=%6.2f\n", c1, c2, c3,
    cnt, table[i].buy, table[i].sell, (double)table[i].qty / cnt);
  }

}
