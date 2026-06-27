int scan(char *p) {
    int n = 0;
    int i;
    for (i = 0; *(p + 1); i++) {
        n = n + 1;
    }
    return n;
}
