int run(int n) {
    int s = 0;
    int i;
    for (i = 0; i < n; i++) {
        int a[3] = {1, 2, 3};
        s = s + a[i % 3];
    }
    return s;
}
