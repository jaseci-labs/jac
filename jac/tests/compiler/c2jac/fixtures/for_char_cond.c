int scan_chars(void) {
    int total = 0;
    for (int i = 0; i < 'z'; i++) {
        total += i;
    }
    return total;
}

int match_char(char c) {
    if (c == 'a') {
        return 1;
    }
    return 0;
}
