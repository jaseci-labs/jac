int countdown(int n) {
    int sum = 0;
    int i;
    for (i = n; i > 0; i--) {
        sum = sum + i;
    }
    return sum;
}

int spin(void) {
    int x = 0;
    for (;;) {
        x = x + 1;
        if (x > 10) {
            break;
        }
    }
    return x;
}
