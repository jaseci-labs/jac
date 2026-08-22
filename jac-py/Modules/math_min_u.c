/* Header-free extract: unsigned minimum. */

unsigned long
math_min_u(unsigned long a, unsigned long b)
{
    if (a < b) {
        return a;
    }
    return b;
}
