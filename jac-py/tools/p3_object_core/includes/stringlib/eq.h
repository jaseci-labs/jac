#ifndef STRINGLIB_EQ_H
#define STRINGLIB_EQ_H

#include "Python.h"

static inline int
unicode_eq(PyObject *str1, PyObject *str2)
{
    (void)str1;
    (void)str2;
    return 0;
}

#endif /* STRINGLIB_EQ_H */
