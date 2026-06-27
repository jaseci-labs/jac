void *malloc(unsigned int size);
void *realloc(void *ptr, unsigned int size);
void free(void *ptr);

int sum_then_free(int n, int *p) {
    int s = 0;
    for (int i = 0; i < n; i++) {
        s += p[i];
        free(p);
    }
    return s;
}

int grow_in_loop(int n, int *arr) {
    int s = 0;
    for (int i = 0; i < n; i++) {
        arr = realloc(arr, i);
        s += arr[i];
    }
    return s;
}
