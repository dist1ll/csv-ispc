ispc csv.ispc -h csv_ispc.h -o optim.o --target=avx2-i8x32
gcc main.c optim.o -static -o main

