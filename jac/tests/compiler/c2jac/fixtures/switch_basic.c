int classify(int x) {
    int r = 0;
    switch (x) {
        case 1:
        case 2:
            r = 10;
            break;
        case 3:
            r = 20;
            break;
        default:
            r = -1;
    }
    return r;
}
