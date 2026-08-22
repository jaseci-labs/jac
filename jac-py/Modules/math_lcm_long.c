/* Header-free extract from Modules/mathmodule.c (lcm on long, via gcd). */

static long
_abs_long(long x)
{
    if (x < 0) {
        return -x;
    }
    return x;
}

static long
_gcd_long(long a, long b)
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

long
math_lcm_long(long a, long b)
{
    long g;
    if (a == 0 || b == 0) {
        return 0;
    }
    g = _gcd_long(a, b);
    a = _abs_long(a);
    b = _abs_long(b);
    return (a / g) * b;
}
