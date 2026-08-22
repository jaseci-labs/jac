int counter;

void tick(void) {
    counter = counter + 1;
}

int run(int n) {
    int i;
    for (i = 0; i < n; tick()) {
        i = i + 1;
    }
    return counter;
}
