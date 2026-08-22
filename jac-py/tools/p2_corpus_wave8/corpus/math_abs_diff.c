/* Header-free extract: absolute difference of two unsigned longs. */

unsigned long
math_abs_diff(unsigned long a, unsigned long b)
{
    if (a >= b) {
        return a - b;
    }
    return b - a;
}
