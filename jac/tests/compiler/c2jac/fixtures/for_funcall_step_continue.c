int counter;

void tick(void) { counter = counter + 1; }

int run(int n) {
    int i;
    int s = 0;
    for (i = 0; i < n; tick()) {
        if (i == n) {
            continue;
        }
        i = i + 1;
        s = s + i;
    }
    return s + counter;
}
