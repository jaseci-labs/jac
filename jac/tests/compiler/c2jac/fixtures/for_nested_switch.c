int clean(int n) {
    int s = 0;
    int i;
    for (i = 0; i < n; i++) {
        switch (i) {
            case 0:
                s = s + 1;
                break;
            case 1:
                s = s + 2;
                break;
            default:
                s = s + 3;
        }
    }
    return s;
}

int dirty(int n) {
    int s = 0;
    int i;
    for (i = 0; i < n; i++) {
        switch (i) {
            case 0:
                s = s + 1;
            case 1:
                s = s + 2;
                break;
            default:
                s = s + 3;
        }
    }
    return s;
}
