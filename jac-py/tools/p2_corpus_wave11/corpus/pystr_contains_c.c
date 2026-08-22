/* Header-free extract: substring search in NUL-terminated haystack. */

int
pystr_contains_c(const char *hay, const char *needle)
{
    unsigned long i;
    unsigned long j;
    if (hay == 0 || needle == 0) {
        return 0;
    }
    if (needle[0] == 0) {
        return 1;
    }
    i = 0;
    while (hay[i] != 0) {
        j = 0;
        while (needle[j] != 0 && hay[i + j] != 0
               && ((hay[i + j] & 255) == (needle[j] & 255))) {
            j += 1;
        }
        if (needle[j] == 0) {
            return 1;
        }
        i += 1;
    }
    return 0;
}
