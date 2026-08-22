/* Header-free extract from Python/pyctype.c (Py_ISCNTRL-style check). */

#define PY_CTF_CNTRL 0x01

static unsigned int
_py_ctype_flags(unsigned char c)
{
    if (c <= 0x1f || c == 0x7f) {
        return PY_CTF_CNTRL;
    }
    return 0;
}

int
pyctype_iscntrl(unsigned char c)
{
    return (_py_ctype_flags(c) & PY_CTF_CNTRL) != 0;
}
