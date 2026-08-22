/* Header-free extract from Modules/mathmodule.c (count_set_bits). */

unsigned long
math_count_set_bits(unsigned long n)
{
    unsigned long count = 0;
    while (n != 0) {
        ++count;
        n &= n - 1;
    }
    return count;
}
