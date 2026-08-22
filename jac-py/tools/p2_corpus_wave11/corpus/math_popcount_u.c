/* Header-free extract: population count of unsigned long bits. */

unsigned long
math_popcount_u(unsigned long n)
{
    unsigned long c;
    c = 0;
    while (n != 0) {
        c += n & 1UL;
        n >>= 1;
    }
    return c;
}
