/* Header-free extract: count leading zeros in low 32 bits; 0 -> 32. */

int
math_clz32_small(unsigned long n)
{
    unsigned long x;
    int r;
    x = n & 0xffffffffUL;
    if (x == 0) {
        return 32;
    }
    r = 0;
    if ((x & 0xffff0000UL) == 0) {
        r += 16;
        x <<= 16;
    }
    if ((x & 0xff000000UL) == 0) {
        r += 8;
        x <<= 8;
    }
    if ((x & 0xf0000000UL) == 0) {
        r += 4;
        x <<= 4;
    }
    if ((x & 0xc0000000UL) == 0) {
        r += 2;
        x <<= 2;
    }
    if ((x & 0x80000000UL) == 0) {
        r += 1;
    }
    return r;
}
