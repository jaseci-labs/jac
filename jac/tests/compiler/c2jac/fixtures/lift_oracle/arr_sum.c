int arr[5];

/* Fixed array → list[int] on lift; jac2c cannot re-emit this. */
int arr_fill(void) {
    int i;
    for (i = 0; i < 5; i = i + 1) {
        arr[i] = i + 1;
    }
    return 0;
}

int arr_sum(void) {
    int i;
    int total;
    total = 0;
    for (i = 0; i < 5; i = i + 1) {
        total = total + arr[i];
    }
    return total;
}

int run_arr_sum(void) {
    arr_fill();
    return arr_sum();
}
