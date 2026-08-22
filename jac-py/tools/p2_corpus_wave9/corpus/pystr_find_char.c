/* Header-free extract: first index of char in NUL-terminated string; -1 if absent.
 * Compare via & 255 (no unsigned-char casts) so c2jac lifts without W4201. */

int
pystr_find_char(const char *s, int ch)
{
    int i;
    int want;
    int got;
    if (s == 0) {
        return -1;
    }
    want = ch & 255;
    i = 0;
    while (s[i] != 0) {
        got = s[i] & 255;
        if (got == want) {
            return i;
        }
        i += 1;
    }
    return -1;
}
