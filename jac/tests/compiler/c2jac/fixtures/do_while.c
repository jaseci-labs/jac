int countdown(int n) {
    int s = 0;
    do {
        s = s + n;
        n = n - 1;
    } while (n > 0);
    return s;
}
