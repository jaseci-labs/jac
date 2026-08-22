/* Header-free extract: unsigned lcm via gcd; 0 if either arg is 0. */

unsigned long
math_gcd_u(unsigned long a, unsigned long b)
{
    unsigned long t;
    while (b != 0) {
        t = a % b;
        a = b;
        b = t;
    }
    return a;
}

unsigned long
math_lcm_u(unsigned long a, unsigned long b)
{
    unsigned long g;
    if (a == 0 || b == 0) {
        return 0;
    }
    g = math_gcd_u(a, b);
    return (a / g) * b;
}
