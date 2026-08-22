int sum_odd(int n) {
    int s = 0;
    do {
        if (n % 2 == 0) {
            n = n - 1;
            continue;
        }
        s = s + n;
        n = n - 1;
    } while (n > 0);
    return s;
}
