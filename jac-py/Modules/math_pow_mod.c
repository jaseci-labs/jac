/* Header-free extract: unsigned (base**exp) % mod; mod==0 -> 0. */

unsigned long
math_pow_mod(unsigned long base, unsigned long exp, unsigned long mod)
{
    unsigned long result;
    if (mod == 0) {
        return 0;
    }
    result = 1;
    base = base % mod;
    while (exp > 0) {
        if (exp & 1UL) {
            result = (result * base) % mod;
        }
        base = (base * base) % mod;
        exp >>= 1;
    }
    return result;
}
