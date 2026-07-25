int sink(int v);

int run(int n) {
    int total = 0;
    for (int i = 0; i < n; i++) {
        total = total + sink(i);
        if (!total) {
            total = 1;
        }
    }
    return total;
}
