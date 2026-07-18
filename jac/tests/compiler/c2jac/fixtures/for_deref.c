int sum_deref(int *p, int n) {
    int s = 0;
    int i;
    for (i = 0; i < n; i++) {
        s += *p;
    }
    return s;
}

int scale_inplace(int *p, int n) {
    int i;
    for (i = 0; i < n; i++) {
        *p += i;
    }
    return *p;
}

int sum_computed_deref(int *p, int n) {
    int s = 0;
    int i;
    for (i = 0; i < n; i++) {
        s += *(p + 1);
    }
    return s;
}
