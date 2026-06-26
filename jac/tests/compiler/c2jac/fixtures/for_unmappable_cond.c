int scan(char *p) {
    int n = 0;
    int i;
    for (i = 0; *p; i++) {
        n = n + 1;
    }
    return n;
}
