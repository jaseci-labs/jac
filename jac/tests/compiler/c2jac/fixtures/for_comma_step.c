int run(int n) {
    int s = 0;
    int i = 0;
    int j = 0;
    for (i = 0; i < n; i++, j++) {
        s = s + i + j;
    }
    return s;
}
