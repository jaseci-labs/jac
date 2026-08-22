typedef struct _object PyObject;

PyObject *identity(PyObject *obj) {
    return obj;
}

void clear_slot(PyObject **slot) {
    *slot = NULL;
}

PyObject *maybe(PyObject *obj) {
    if (obj == NULL) {
        return NULL;
    }
    return obj;
}
