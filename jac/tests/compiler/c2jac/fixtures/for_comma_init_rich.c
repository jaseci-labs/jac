int seed(void);

int run(int n) {
    int s = 0;
    int i;
    for (i = 0, seed(); i < n; i++) {
        s = s + i;
    }
    return s;
}
