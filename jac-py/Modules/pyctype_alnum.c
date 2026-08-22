/* Header-free extract from Python/pyctype.c (Py_ISALNUM-style check). */

#define PY_CTF_UPPER 0x02
#define PY_CTF_LOWER 0x04
#define PY_CTF_DIGIT 0x08
#define PY_CTF_ALNUM (PY_CTF_UPPER | PY_CTF_LOWER | PY_CTF_DIGIT)

static unsigned int
_py_ctype_flags(unsigned char c)
{
    if (c >= '0' && c <= '9') {
        return PY_CTF_DIGIT;
    }
    if (c >= 'A' && c <= 'Z') {
        return PY_CTF_UPPER;
    }
    if (c >= 'a' && c <= 'z') {
        return PY_CTF_LOWER;
    }
    return 0;
}

int
pyctype_isalnum(unsigned char c)
{
    return (_py_ctype_flags(c) & PY_CTF_ALNUM) != 0;
}
