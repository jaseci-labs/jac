/* Header-free extract from Python/pyctype.c (Py_ISXDIGIT-style check). */

#define PY_CTF_DIGIT 0x04
#define PY_CTF_XDIGIT 0x10

static unsigned int
_py_ctype_flags(unsigned char c)
{
    if (c >= '0' && c <= '9') {
        return PY_CTF_DIGIT | PY_CTF_XDIGIT;
    }
    if ((c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f')) {
        return PY_CTF_XDIGIT;
    }
    return 0;
}

int
pyctype_isxdigit(unsigned char c)
{
    return (_py_ctype_flags(c) & PY_CTF_XDIGIT) != 0;
}
