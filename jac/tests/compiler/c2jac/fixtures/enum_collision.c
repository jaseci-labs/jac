int test_a(void) {
    enum { VAL_A = 0, VAL_B = 1 } e1;
    return VAL_A;
}

int test_b(void) {
    enum { VAL_A = 10, VAL_C = 11 } e2;
    return VAL_A;
}
