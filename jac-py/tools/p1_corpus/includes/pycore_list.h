#ifndef PYCORE_LIST_H
#define PYCORE_LIST_H

#include "Python.h"

#define _PyList_CAST(op) ((PyListObject *)(op))
#define _PyList_ITEMS(list) (((PyListObject *)(list))->ob_item)

#endif /* PYCORE_LIST_H */
