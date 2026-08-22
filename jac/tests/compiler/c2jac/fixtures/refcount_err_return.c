typedef struct {
} PyObject;

void Py_INCREF(PyObject *o);
void Py_DECREF(PyObject *o);
void Py_XDECREF(PyObject *o);
void Py_CLEAR(PyObject *o);
PyObject *Py_NewRef(PyObject *o);
PyObject *Py_XNewRef(PyObject *o);
void PyErr_SetString(PyObject *exc, const char *msg);

PyObject *PyExc_ValueError;
PyObject *PyExc_TypeError;

PyObject *borrow(PyObject *obj) {
    Py_INCREF(obj);
    return obj;
}

void drop(PyObject *obj) {
    Py_DECREF(obj);
    Py_XDECREF(obj);
}

void reset_slot(PyObject *slot) {
    Py_CLEAR(slot);
}

PyObject *copy_ref(PyObject *obj) {
    return Py_NewRef(obj);
}

void touch_ref(PyObject *obj) {
    Py_XNewRef(obj);
}

PyObject *fail_value(void) {
    PyErr_SetString(PyExc_ValueError, "bad arg");
    return NULL;
}

int fail_int(void) {
    PyErr_SetString(PyExc_TypeError, "wrong type");
    return -1;
}

PyObject *fetch(PyObject *lst, int i);

PyObject *get_item(PyObject *lst, int i) {
    PyObject *item = fetch(lst, i);
    if (item == NULL)
        return NULL;
    return item;
}
