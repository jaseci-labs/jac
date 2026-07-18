struct S { int x; };

int build(void) {
    struct S a[2];
    a[0].x = 1;
    a[1].x = 2;
    return a[0].x;
}
