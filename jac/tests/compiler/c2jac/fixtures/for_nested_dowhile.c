int clean(int n) {
    int s = 0;
    int i;
    for (i = 0; i < n; i++) {
        int k = 0;
        do {
            s = s + k;
            k = k + 1;
        } while (k < i);
    }
    return s;
}

int dirty(int n) {
    int s = 0;
    int i;
    for (i = 0; i < n; i++) {
        int k = 0;
        do {
            k = k + 1;
            if (k == i) {
                continue;
            }
            s = s + k;
        } while (k < i);
    }
    return s;
}
