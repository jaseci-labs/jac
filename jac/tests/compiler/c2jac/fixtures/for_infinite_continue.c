int sum_until(int n) {
    int sum = 0;
    int i = 0;
    for (;;) {
        i = i + 1;
        if (i > n) {
            break;
        }
        if (i == 2) {
            continue;
        }
        sum = sum + i;
    }
    return sum;
}
