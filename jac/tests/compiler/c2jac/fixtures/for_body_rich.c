int classify(int n) {
    int result;
    int i;
    for (i = 0; i < n; i++) {
        int local;
        if (i < 0) {
            result = -1;
        } else {
            result = 1;
        }
        if (i == 5) {
            return result;
        }
    }
    return 0;
}
