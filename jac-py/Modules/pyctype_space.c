/* Header-free extract from Python/pyctype.c (Py_ISSPACE-style check). */

#define PY_CTF_SPACE 0x01

static unsigned int
_py_ctype_flags(unsigned char c)
{
    if (c == ' ' || c == '\t' || c == '\n' || c == '\v' || c == '\f' || c == '\r') {
        return PY_CTF_SPACE;
    }
    return 0;
}

int
pyctype_isspace(unsigned char c)
{
    return (_py_ctype_flags(c) & PY_CTF_SPACE) != 0;
}
