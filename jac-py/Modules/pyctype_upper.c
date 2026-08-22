/* Header-free extract from Python/pyctype.c (Py_ISUPPER-style check). */

#define PY_CTF_UPPER 0x01

static unsigned int
_py_ctype_flags(unsigned char c)
{
    if (c >= 'A' && c <= 'Z') {
        return PY_CTF_UPPER;
    }
    return 0;
}

int
pyctype_isupper(unsigned char c)
{
    return (_py_ctype_flags(c) & PY_CTF_UPPER) != 0;
}
