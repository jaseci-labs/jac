/* Header-free extract from Python/pyctype.c (Py_ISPUNCT-style check). */

#define PY_CTF_PUNCT 0x01

static unsigned int
_py_ctype_flags(unsigned char c)
{
    if ((c >= 0x21 && c <= 0x2f) ||
        (c >= 0x3a && c <= 0x40) ||
        (c >= 0x5b && c <= 0x60) ||
        (c >= 0x7b && c <= 0x7e)) {
        return PY_CTF_PUNCT;
    }
    return 0;
}

int
pyctype_ispunct(unsigned char c)
{
    return (_py_ctype_flags(c) & PY_CTF_PUNCT) != 0;
}
