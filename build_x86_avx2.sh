ispc csv.ispc -h csv_ispc.h -o optim.o --target=avx2-i8x32
g++ main.cpp optim.o -static -o main

