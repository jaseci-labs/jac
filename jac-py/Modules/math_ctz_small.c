/* Header-free extract: count trailing zero bits; 0 -> -1. */

int
math_ctz_small(unsigned long n)
{
    int r;
    if (n == 0) {
        return -1;
    }
    r = 0;
    while ((n & 1UL) == 0) {
        n >>= 1;
        r += 1;
    }
    return r;
}
