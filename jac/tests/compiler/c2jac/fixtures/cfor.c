int sum_for(int n) {
    int total = 0;
    int i;
    for (i = 0; i < n; i++) {
        if (i == 3) {
            continue;
        }
        total = total + i;
    }
    return total;
}

int count_odds(int n) {
    int count = 0;
    int i;
    for (i = 0; i < n; i++) {
        if (i % 2 == 0) {
            continue;
        }
        count = count + 1;
    }
    return count;
}
