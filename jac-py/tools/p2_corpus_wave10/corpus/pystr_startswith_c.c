/* Header-free extract: NUL-terminated prefix check. */

int
pystr_startswith_c(const char *s, const char *prefix)
{
    unsigned long i;
    if (s == 0 || prefix == 0) {
        return 0;
    }
    i = 0;
    while (prefix[i] != 0) {
        if (s[i] == 0) {
            return 0;
        }
        if ((s[i] & 255) != (prefix[i] & 255)) {
            return 0;
        }
        i += 1;
    }
    return 1;
}
