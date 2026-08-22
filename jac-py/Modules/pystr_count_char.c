/* Header-free extract: count occurrences of char in NUL-terminated string.
 * Compare via & 255 (no unsigned-char casts) so c2jac lifts without W4201. */

unsigned long
pystr_count_char(const char *s, int ch)
{
    unsigned long n;
    unsigned long i;
    int want;
    int got;
    if (s == 0) {
        return 0;
    }
    want = ch & 255;
    n = 0;
    i = 0;
    while (s[i] != 0) {
        got = s[i] & 255;
        if (got == want) {
            n += 1;
        }
        i += 1;
    }
    return n;
}
