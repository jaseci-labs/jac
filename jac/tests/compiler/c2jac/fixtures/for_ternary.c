int clamp_sum(int n, int hi) {
    int s = 0;
    int i;
    for (i = 0; i < n; i++) {
        s += i > hi ? hi : i;
    }
    return s;
}
