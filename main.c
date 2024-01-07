#include "csv_ispc.h"
#include <stdio.h>
#include <stdlib.h>

#ifdef _WIN64
  #include <windows.h>
  #include <winbase.h>
#elif __unix
  #include <sys/mman.h>
  #include <sys/stat.h>
#endif

int main(int argc, char *argv[]) {
  if (argc != 2) {
    printf("Error: expected path to csv file.\nUsage: ./main <PATH>\n");
    exit(1);
  }
  struct Aggregate *table;

#ifdef _WIN64
  HANDLE f = CreateFile(argv[1], GENERIC_READ, 
            FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING, 
            FILE_ATTRIBUTE_NORMAL, NULL);
  LARGE_INTEGER map_size;
  if (!GetFileSizeEx(f, &map_size)) {
      CloseHandle(f);
      exit(1);
  }

  HANDLE mapping = CreateFileMappingA(f, 0, PAGE_READONLY, 
                map_size.HighPart, map_size.LowPart, 0);
  if (mapping == 0) {
    printf("Error creating file mapping.\n");
    exit(1);
  }
  uint8_t* addr = (uint8_t*) MapViewOfFile(mapping, FILE_MAP_READ, 0, 0, 0);
  if (!addr) {
    printf("Couldn't create view of file.\n");
    exit(1);
  }
  table = process_csv(addr, map_size.QuadPart);
  UnmapViewOfFile(addr);
  CloseHandle(mapping);
#elif __unix
  FILE *f = fopen(argv[1], "rb");
  if (f == NULL) {
    printf("Error opening file.\n");
    exit(1);
  }  int fd = fileno(f);

  struct stat st;
  fstat(fd, &st);

  /* File size increased by 8KiB (or 12KiB if already 4KiB aligned) */
  long long map_size = st.st_size;
  if ((st.st_size & 0xfff) != 0) {
    map_size = (st.st_size + 0x2000) & (~0xfff);
  }
  uint8_t *addr =
      (uint8_t *)mmap(NULL, map_size, PROT_READ, MAP_PRIVATE | MAP_POPULATE, fd, 0);
  table = process_csv(addr, st.st_size);
  munmap((void *)addr, map_size);
  fclose(f);
#endif

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
