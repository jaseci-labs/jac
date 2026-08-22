def math_count_set_bits(n: int) -> int {
    count: int = 0;
    while (n != 0) {
        count += 1;
        n &= n - 1;
    }

    return count;
}
