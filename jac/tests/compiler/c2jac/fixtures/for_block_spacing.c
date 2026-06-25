int accumulate(int n) {
    int total = 0;
    int i;
    for (i = 0; i < n; i++) {
        total = total + i;
        total = total + 1;
    }
    return total;
}
