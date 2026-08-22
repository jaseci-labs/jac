/*[clinic input]
preserve
[clinic start generated code]*/

#include "pycore_modsupport.h"    // _PyArg_CheckPositional()

PyDoc_STRVAR(bool_new__doc__,
"bool(object=False, /)\n"
"--\n"
"\n"
"bool(object=False, /)\n"
"\n"
"Returns True when the argument is true, False otherwise.\n"
"\n"
"The builtins True and False are the only two instances of the class bool.\n"
"The class bool is a subclass of the class int, and cannot be subclassed.");

static PyObject *
bool_new_impl(PyTypeObject *type, PyObject *object);

static PyObject *
bool_new(PyTypeObject *type, PyObject *args, PyObject *kwargs)
{
    PyObject *return_value = NULL;
    PyTypeObject *base_tp = &PyBool_Type;
    PyObject *object = NULL;

    if ((type == base_tp || type->tp_init == base_tp->tp_init) &&
        !_PyArg_NoKeywords("bool", kwargs)) {
        goto exit;
    }
    if (!_PyArg_CheckPositional("bool", PyTuple_GET_SIZE(args), 0, 1)) {
        goto exit;
    }
    if (PyTuple_GET_SIZE(args) < 1) {
        goto skip_optional;
    }
    object = PyTuple_GET_ITEM(args, 0);
skip_optional:
    return_value = bool_new_impl(type, object);

exit:
    return return_value;
}
/*[clinic end generated code: output=2e7f9a2c4c3ec633 input=a9049054013a1b77]*/
