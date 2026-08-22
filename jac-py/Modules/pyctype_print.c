/* Header-free extract from Python/pyctype.c (Py_ISPRINT-style check). */

#define PY_CTF_PRINT 0x01

static unsigned int
_py_ctype_flags(unsigned char c)
{
    if (c >= 0x20 && c <= 0x7e) {
        return PY_CTF_PRINT;
    }
    return 0;
}

int
pyctype_isprint(unsigned char c)
{
    return (_py_ctype_flags(c) & PY_CTF_PRINT) != 0;
}
