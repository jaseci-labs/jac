/* Header-free extract: unsigned power-of-two predicate. */

int
math_pow2_check(unsigned long n)
{
    if (n == 0) {
        return 0;
    }
    return (n & (n - 1)) == 0;
}
