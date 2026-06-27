int scan(char *p) {
    int n = 0;
    int i;
    for (i = 0; *(p + 1); i++) {
        int j;
        for (j = i; j > 0; j--) {
            n = n + 1;
        }
    }
    return n;
}
