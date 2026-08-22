/* Header-free extract: NUL-terminated suffix check. */

unsigned long
pystr_len_u(const char *s)
{
    unsigned long n;
    n = 0;
    if (s == 0) {
        return 0;
    }
    while (s[n] != 0) {
        n += 1;
    }
    return n;
}

int
pystr_endswith_c(const char *s, const char *suffix)
{
    unsigned long ns;
    unsigned long nfx;
    unsigned long i;
    if (s == 0 || suffix == 0) {
        return 0;
    }
    ns = pystr_len_u(s);
    nfx = pystr_len_u(suffix);
    if (nfx > ns) {
        return 0;
    }
    i = 0;
    while (i < nfx) {
        if ((s[ns - nfx + i] & 255) != (suffix[i] & 255)) {
            return 0;
        }
        i += 1;
    }
    return 1;
}
