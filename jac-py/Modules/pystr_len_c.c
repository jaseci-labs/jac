/* Header-free extract: C-string length (NUL-terminated). */

unsigned long
pystr_len_c(const char *s)
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
