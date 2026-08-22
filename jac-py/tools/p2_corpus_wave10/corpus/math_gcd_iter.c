/* Header-free extract: iterative unsigned gcd (Euclid). */

unsigned long
math_gcd_iter(unsigned long a, unsigned long b)
{
    unsigned long t;
    while (b != 0) {
        t = a % b;
        a = b;
        b = t;
    }
    return a;
}
