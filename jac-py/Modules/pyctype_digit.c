/* Header-free extract from Python/pyctype.c (Py_ISDIGIT-style check). */

#define PY_CTF_DIGIT 0x04

static unsigned int
_py_ctype_flags(unsigned char c)
{
    if (c >= '0' && c <= '9') {
        return PY_CTF_DIGIT;
    }
    return 0;
}

int
pyctype_isdigit(unsigned char c)
{
    return (_py_ctype_flags(c) & PY_CTF_DIGIT) != 0;
}
