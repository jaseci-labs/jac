/* Header-free extract: floor(log2(n)) for n > 0; returns -1 for 0. */

int
math_ilog2_small(unsigned long n)
{
    int r;
    if (n == 0) {
        return -1;
    }
    r = 0;
    while (n > 1) {
        n >>= 1;
        r += 1;
    }
    return r;
}
