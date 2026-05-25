impl random_int(max_val: int) -> int {
    global _rand_state;
    _rand_state = (_rand_state * 1103515245 + 12345) % 2147483648;
    if max_val <= 0 {
        return 0;
    }
    return _rand_state % max_val;
}
