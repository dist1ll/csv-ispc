ispc csv.ispc -h csv_ispc.h -o optim.o --target=avx2-i8x32
zig cc main.c optim.o -static -O3 -o main.out

