/* Header-free extract from Modules/mathmodule.c (small factorial core). */

unsigned long
math_factorial_small(unsigned long n)
{
    unsigned long result = 1;
    unsigned long i = 2;
    if (n <= 1) {
        return 1;
    }
    while (i <= n) {
        result *= i;
        i = i + 1;
    }
    return result;
}
