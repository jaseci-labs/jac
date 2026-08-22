/* Header-free extract: strcmp-style signed compare on NUL-terminated strings. */

int
pystr_cmp_c(const char *a, const char *b)
{
    unsigned long i;
    int ca;
    int cb;
    if (a == 0 && b == 0) {
        return 0;
    }
    if (a == 0) {
        return -1;
    }
    if (b == 0) {
        return 1;
    }
    i = 0;
    while (1) {
        ca = a[i] & 255;
        cb = b[i] & 255;
        if (ca != cb) {
            return ca - cb;
        }
        if (ca == 0) {
            return 0;
        }
        i += 1;
    }
}
