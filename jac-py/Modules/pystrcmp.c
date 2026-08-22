static int py_tolower(int c) {
    return (c >= 'A' && c <= 'Z') ? (c + 32) : c;
}

int PyOS_mystrnicmp(const char *s1, const char *s2, long size) {
    const unsigned char *p1, *p2;
    if (size == 0)
        return 0;
    p1 = (const unsigned char *)s1;
    p2 = (const unsigned char *)s2;
    for (; (--size > 0) && *p1 && *p2 && (py_tolower(*p1) == py_tolower(*p2));
         p1++, p2++) {
        ;
    }
    return py_tolower(*p1) - py_tolower(*p2);
}

int PyOS_mystricmp(const char *s1, const char *s2) {
    const unsigned char *p1 = (const unsigned char *)s1;
    const unsigned char *p2 = (const unsigned char *)s2;
    for (; *p1 && *p2 && (py_tolower(*p1) == py_tolower(*p2)); p1++, p2++) {
        ;
    }
    return (py_tolower(*p1) - py_tolower(*p2));
}
