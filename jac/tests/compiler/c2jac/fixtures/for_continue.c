int sum_odd_descending(int n) {
    int sum = 0;
    int i;
    for (i = n; i > 0; i--) {
        if (i == 2) {
            continue;
        }
        sum = sum + i;
    }
    return sum;
}
