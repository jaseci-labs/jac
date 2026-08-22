def math_pow_mod(base: int, exp: int, mod: int) -> int {
    result: int = 0;
    if (mod == 0) {
        return 0;
    }

    result = 1;
    base = base % mod;
    while (exp > 0) {
        if (exp & 1) {
            result = (result * base) % mod;
        }

        base = (base * base) % mod;
        exp >>= 1;
    }

    return result;
}
