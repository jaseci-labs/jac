int run(int n) {
    int s = 0;
    for (int i = 0, j = 0; i < n; i++) {
        j = j + 2;
        s = s + i + j;
    }
    return s;
}
