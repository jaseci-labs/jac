int truncate_sum(int n) {
    int total = 0;
    int i;
    for (i = 0; i < n; i++) {
        total = total + (int)(i / 2);
    }
    return total;
}

int deref_sum(int *a, int n) {
    int total = 0;
    int i;
    for (i = 0; i < n; i++) {
        total = total + ((int *)a)[i];
    }
    return total;
}
