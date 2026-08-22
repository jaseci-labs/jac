static unsigned char
_py_tolower(unsigned char c)
{
    if (c >= 'A' && c <= 'Z') {
        return (unsigned char)(c + ('a' - 'A'));
    }
    return c;
}

int
PyOS_mystrnicmp(const char *s1, const char *s2, long size)
{
    const unsigned char *p1;
    const unsigned char *p2;
    if (size == 0) {
        return 0;
    }
    p1 = (const unsigned char *)s1;
    p2 = (const unsigned char *)s2;
    for (; (--size > 0) && *p1 && *p2 && (_py_tolower(*p1) == _py_tolower(*p2));
         p1++, p2++) {
    }
    return (int)_py_tolower(*p1) - (int)_py_tolower(*p2);
}
