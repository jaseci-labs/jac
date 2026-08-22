/* Header-free extract from Python/pyctype.c (Py_ISGRAPH-style check). */

#define PY_CTF_GRAPH 0x01

static unsigned int
_py_ctype_flags(unsigned char c)
{
    if (c >= 0x21 && c <= 0x7e) {
        return PY_CTF_GRAPH;
    }
    return 0;
}

int
pyctype_isgraph(unsigned char c)
{
    return (_py_ctype_flags(c) & PY_CTF_GRAPH) != 0;
}
