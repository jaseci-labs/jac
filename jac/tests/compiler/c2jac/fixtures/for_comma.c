int touch(int x) { return x; }

int pure_comma(int n) {
    int s = 0;
    int i;
    for (i = 0; i < n; i++) {
        s += (0, i);
    }
    return s;
}

int impure_comma(int n) {
    int s = 0;
    int i;
    for (i = 0; i < n; i++) {
        s += (touch(i), i);
    }
    return s;
}
