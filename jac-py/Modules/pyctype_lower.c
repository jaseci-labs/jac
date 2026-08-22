/* Header-free extract from Python/pyctype.c (Py_ISLOWER-style check). */

#define PY_CTF_LOWER 0x01

static unsigned int
_py_ctype_flags(unsigned char c)
{
    if (c >= 'a' && c <= 'z') {
        return PY_CTF_LOWER;
    }
    return 0;
}

int
pyctype_islower(unsigned char c)
{
    return (_py_ctype_flags(c) & PY_CTF_LOWER) != 0;
}
