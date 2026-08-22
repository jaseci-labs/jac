/* Header-free extract from Python/pyctype.c (Py_ISALPHA-style check). */

#define PY_CTF_UPPER 0x02
#define PY_CTF_LOWER 0x04

static unsigned int
_py_ctype_flags(unsigned char c)
{
    if (c >= 'A' && c <= 'Z') {
        return PY_CTF_UPPER;
    }
    if (c >= 'a' && c <= 'z') {
        return PY_CTF_LOWER;
    }
    return 0;
}

int
pyctype_isalpha(unsigned char c)
{
    unsigned int flags = _py_ctype_flags(c);
    return (flags & (PY_CTF_UPPER | PY_CTF_LOWER)) != 0;
}
