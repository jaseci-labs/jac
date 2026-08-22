/* Header-free extract: unsigned maximum. */

unsigned long
math_max_u(unsigned long a, unsigned long b)
{
    if (a > b) {
        return a;
    }
    return b;
}
