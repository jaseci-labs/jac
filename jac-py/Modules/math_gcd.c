/* Header-free extract from Modules/mathmodule.c (gcd fast path on long). */

static long
_abs_long(long x)
{
    if (x < 0) {
        return -x;
    }
    return x;
}

long
math_gcd_long(long a, long b)
{
    a = _abs_long(a);
    b = _abs_long(b);
    while (b != 0) {
        long t = b;
        b = a % b;
        a = t;
    }
    return a;
}
