/* Header-free extract from Python/pyctype.c (Py_ISBLANK-style check). */

#define PY_CTF_BLANK 0x01

static unsigned int
_py_ctype_flags(unsigned char c)
{
    if (c == ' ' || c == '\t') {
        return PY_CTF_BLANK;
    }
    return 0;
}

int
pyctype_isblank(unsigned char c)
{
    return (_py_ctype_flags(c) & PY_CTF_BLANK) != 0;
}
