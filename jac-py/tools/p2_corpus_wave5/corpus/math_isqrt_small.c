/* Header-free extract: small unsigned isqrt via Newton iteration. */

unsigned long
math_isqrt_small(unsigned long n)
{
    unsigned long x;
    unsigned long y;
    if (n <= 1) {
        return n;
    }
    x = n;
    for (;;) {
        y = (x + n / x) / 2;
        if (y >= x) {
            return x;
        }
        x = y;
    }
}
