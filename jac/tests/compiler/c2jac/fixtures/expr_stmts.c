int g(int x) {
    return x;
}

int f(int n) {
    g(n);
    return n;
}

int counter(int n) {
    int i = 0;
    i++;
    return i;
}
