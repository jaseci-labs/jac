/* CPython layouts and public argument binding for the native Jac pickle engine. */
#include <Python.h>
#include <stddef.h>
#include <stdint.h>
#define H(p) ((uint64_t)(uintptr_t)(p))
#define O(h) ((PyObject *)(uintptr_t)(h))
typedef struct {
    PyObject_HEAD void *native;
    PyObject *persistent, *dispatch;
    int busy, initialized, bin, fast, fix_imports, reader;
} Codec;
typedef struct {
    PyObject_HEAD Codec *owner;
} Memo;
typedef struct {
    PyObject *pickler, *unpickler, *pickler_memo, *unpickler_memo, *error, *pickling_error,
        *unpickling_error, *bytesio, *dispatch;
} Module;
static PyModuleDef definition;
extern void jac_release(void *);
extern void *jacpy_pickler_new(void), *jacpy_unpickler_new(void);
extern void jacpy_pickler_clear(void *), jacpy_unpickler_clear(void *),
    jacpy_pickler_memo_clear(void *), jacpy_unpickler_memo_clear(void *);
extern int64_t jacpy_pickler_init(void *, uint64_t, int64_t, int64_t, uint64_t, uint64_t);
extern int64_t jacpy_unpickler_init(void *, uint64_t, uint64_t, uint64_t, uint64_t, uint64_t,
                                    uint64_t);
extern int64_t jacpy_pickler_dump(void *, uint64_t, uint64_t, uint64_t, uint64_t, int64_t);
extern uint64_t jacpy_unpickler_load(void *, uint64_t, uint64_t),
    jacpy_unpickler_find(void *, uint64_t, uint64_t, int64_t);
extern uint64_t jacpy_pickler_field(void *, int64_t), jacpy_unpickler_field(void *, int64_t),
    jacpy_pickler_memo(void *), jacpy_unpickler_memo(void *);
extern int64_t jacpy_unpickler_field_count(void *), jacpy_pickler_size(void *),
    jacpy_unpickler_size(void *);
extern int64_t jacpy_pickler_memo_set(void *, uint64_t), jacpy_unpickler_memo_set(void *, uint64_t);
static Module *module_for(PyTypeObject *type) {
    PyObject *m = PyType_GetModuleByDef(type, &definition);
    return m ? PyModule_GetState(m) : NULL;
}
static int enter(Codec *self) {
    if (self->busy) {
        PyErr_SetString(PyExc_RuntimeError, "pickle object is already in use");
        return -1;
    }
    self->busy = 1;
    return 0;
}
static int codec_clear(PyObject *op) {
    Codec *self = (Codec *)op;
    self->initialized = 0;
    Py_CLEAR(self->persistent);
    Py_CLEAR(self->dispatch);
    if (self->native) {
        if (self->reader)
            jacpy_unpickler_clear(self->native);
        else
            jacpy_pickler_clear(self->native);
    }
    return 0;
}
static int codec_traverse(PyObject *op, visitproc visit, void *arg) {
    Codec *self = (Codec *)op;
    Py_VISIT(Py_TYPE(op));
    Py_VISIT(self->persistent);
    Py_VISIT(self->dispatch);
    if (self->native) {
        int64_t count = self->reader ? jacpy_unpickler_field_count(self->native) : 8;
        for (int64_t i = 0; i < count; i++)
            Py_VISIT(O(self->reader ? jacpy_unpickler_field(self->native, i)
                                    : jacpy_pickler_field(self->native, i)));
    }
    return 0;
}
static void codec_dealloc(PyObject *op) {
    Codec *self = (Codec *)op;
    PyTypeObject *type = Py_TYPE(op);
    PyObject_GC_UnTrack(op);
    codec_clear(op);
    if (self->native)
        jac_release(self->native);
    type->tp_free(op);
    Py_DECREF(type);
}
static PyObject *codec_new(PyTypeObject *type, PyObject *args, PyObject *kw) {
    Module *m = module_for(type);
    if (!m)
        return NULL;
    Codec *self = (Codec *)type->tp_alloc(type, 0);
    if (!self)
        return NULL;
    self->reader = PyType_IsSubtype(type, (PyTypeObject *)m->unpickler);
    self->native = self->reader ? jacpy_unpickler_new() : jacpy_pickler_new();
    self->fix_imports = 1;
    if (!self->native) {
        Py_DECREF(self);
        return PyErr_NoMemory();
    }
    return (PyObject *)self;
}
static PyObject *codec_getattro(PyObject *op, PyObject *name) {
    Codec *self = (Codec *)op;
    if (self->persistent && PyUnicode_Check(name) &&
        PyUnicode_EqualToUTF8(name, self->reader ? "persistent_load" : "persistent_id"))
        return Py_NewRef(self->persistent);
    return PyObject_GenericGetAttr(op, name);
}
static int codec_setattro(PyObject *op, PyObject *name, PyObject *value) {
    Codec *self = (Codec *)op;
    if (PyUnicode_Check(name) &&
        PyUnicode_EqualToUTF8(name, self->reader ? "persistent_load" : "persistent_id")) {
        Py_XINCREF(value);
        Py_XSETREF(self->persistent, value);
        return 0;
    }
    return PyObject_GenericSetAttr(op, name, value);
}
static int pickler_init(PyObject *op, PyObject *args, PyObject *kw) {
    static char *names[] = {"file", "protocol", "fix_imports", "buffer_callback", NULL};
    PyObject *file, *protocol = Py_None, *callback = Py_None;
    int fix = 1;
    if (!PyArg_ParseTupleAndKeywords(args, kw, "O|O$pO:Pickler", names, &file, &protocol, &fix,
                                     &callback))
        return -1;
    long version = protocol == Py_None ? 5 : PyLong_AsLong(protocol);
    if (version == -1 && PyErr_Occurred())
        return -1;
    if (version < 0)
        version = 5;
    if (version > 5) {
        PyErr_SetString(PyExc_ValueError, "pickle protocol must be <= 5");
        return -1;
    }
    if (callback != Py_None && version < 5) {
        PyErr_SetString(PyExc_ValueError, "buffer_callback needs protocol >= 5");
        return -1;
    }
    Codec *self = (Codec *)op;
    if (enter(self) < 0)
        return -1;
    int result = -1;
    Module *m = module_for(Py_TYPE(op));
    PyObject *write = NULL;
    if (!m)
        goto done;
    write = PyObject_GetAttrString(file, "write");
    if (!write) {
        if (PyErr_ExceptionMatches(PyExc_AttributeError)) {
            PyErr_Clear();
            PyErr_SetString(PyExc_TypeError, "file must have a 'write' attribute");
        }
        goto done;
    }
    result = (int)jacpy_pickler_init(self->native, H(write), version, fix,
                                     callback == Py_None ? 0 : H(callback), H(m->pickling_error));
    if (result == 0) {
        self->initialized = 1;
        self->bin = version > 0;
        self->fast = 0;
        self->fix_imports = fix;
    }
done:
    Py_XDECREF(write);
    self->busy = 0;
    return result;
}
static int unpickler_init(PyObject *op, PyObject *args, PyObject *kw) {
    static char *names[] = {"file", "fix_imports", "encoding", "errors", "buffers", NULL};
    PyObject *file, *buffers = Py_None;
    const char *encoding = "ASCII", *errors = "strict";
    int fix = 1;
    if (!PyArg_ParseTupleAndKeywords(args, kw, "O|$pssO:Unpickler", names, &file, &fix, &encoding,
                                     &errors, &buffers))
        return -1;
    Codec *self = (Codec *)op;
    if (enter(self) < 0)
        return -1;
    int result = -1;
    Module *m = module_for(Py_TYPE(op));
    PyObject *read = NULL, *readline = NULL, *enc = NULL, *err = NULL;
    if (!m)
        goto done;
    if (PyObject_GetOptionalAttrString(file, "read", &read) < 0 ||
        PyObject_GetOptionalAttrString(file, "readline", &readline) < 0)
        goto done;
    if (!read || !readline) {
        PyErr_SetString(PyExc_TypeError, "file must have 'read' and 'readline' attributes");
        goto done;
    }
    enc = PyUnicode_FromString(encoding);
    err = PyUnicode_FromString(errors);
    if (!enc || !err)
        goto done;
    result = (int)jacpy_unpickler_init(self->native, H(read), H(readline), H(m->unpickling_error),
                                       buffers == Py_None ? 0 : H(buffers), H(enc), H(err));
    if (result == 0) {
        self->initialized = 1;
        self->fix_imports = fix;
    }
done:
    Py_XDECREF(read);
    Py_XDECREF(readline);
    Py_XDECREF(enc);
    Py_XDECREF(err);
    self->busy = 0;
    return result;
}
static PyObject *pickler_dump(PyObject *op, PyObject *value) {
    Codec *self = (Codec *)op;
    if (!self->initialized) {
        Module *m = module_for(Py_TYPE(op));
        if (m)
            PyErr_SetString(m->pickling_error, "Pickler.__init__() was not called");
        return NULL;
    }
    if (enter(self) < 0)
        return NULL;
    PyObject *persistent = NULL, *reducer = NULL, *dispatch = NULL, *result = NULL;
    Module *m = module_for(Py_TYPE(op));
    if (!m)
        goto done;
    persistent = PyObject_GetAttrString(op, "persistent_id");
    if (!persistent)
        goto done;
    if (PyObject_GetOptionalAttrString(op, "reducer_override", &reducer) < 0 ||
        PyObject_GetOptionalAttrString(op, "dispatch_table", &dispatch) < 0)
        goto done;
    if (!dispatch)
        dispatch = Py_NewRef(m->dispatch);
    if (jacpy_pickler_dump(self->native, H(value), H(persistent), H(reducer), H(dispatch),
                           self->fast) == 0)
        result = Py_NewRef(Py_None);
done:
    Py_XDECREF(persistent);
    Py_XDECREF(reducer);
    Py_XDECREF(dispatch);
    self->busy = 0;
    return result;
}
static PyObject *unpickler_load(PyObject *op, PyObject *unused) {
    Codec *self = (Codec *)op;
    if (!self->initialized) {
        Module *m = module_for(Py_TYPE(op));
        if (m)
            PyErr_SetString(m->unpickling_error, "Unpickler.__init__() was not called");
        return NULL;
    }
    if (enter(self) < 0)
        return NULL;
    PyObject *find = PyObject_GetAttrString(op, "find_class"), *persistent = NULL, *result = NULL;
    if (find)
        persistent = PyObject_GetAttrString(op, "persistent_load");
    if (find && persistent)
        result = O(jacpy_unpickler_load(self->native, H(find), H(persistent)));
    Py_XDECREF(find);
    Py_XDECREF(persistent);
    self->busy = 0;
    return result;
}
static PyObject *persistent_id(PyObject *op, PyObject *value) { Py_RETURN_NONE; }
static PyObject *persistent_load(PyObject *op, PyObject *value) {
    Module *m = module_for(Py_TYPE(op));
    if (m)
        PyErr_SetString(m->unpickling_error, "A load persistent id instruction was encountered, "
                                             "but no persistent_load function was specified.");
    return NULL;
}
static PyObject *find_class(PyObject *op, PyObject *args) {
    PyObject *module, *name;
    if (!PyArg_ParseTuple(args, "OO:find_class", &module, &name))
        return NULL;
    Codec *self = (Codec *)op;
    return O(jacpy_unpickler_find(self->native, H(module), H(name), self->fix_imports));
}
static PyObject *codec_sizeof(PyObject *op, PyObject *unused) {
    Codec *self = (Codec *)op;
    Py_ssize_t size =
        self->reader ? jacpy_unpickler_size(self->native) : jacpy_pickler_size(self->native);
    return size < 0 ? NULL : PyLong_FromSsize_t(Py_TYPE(op)->tp_basicsize + size);
}
static PyObject *memo_copy(PyObject *op, PyObject *unused) {
    Codec *self = ((Memo *)op)->owner;
    return O(self->reader ? jacpy_unpickler_memo(self->native) : jacpy_pickler_memo(self->native));
}
static PyObject *memo_clear(PyObject *op, PyObject *unused) {
    Codec *self = ((Memo *)op)->owner;
    if (self->reader)
        jacpy_unpickler_memo_clear(self->native);
    else
        jacpy_pickler_memo_clear(self->native);
    Py_RETURN_NONE;
}
static PyObject *memo_reduce(PyObject *op, PyObject *unused) {
    PyObject *copy = memo_copy(op, NULL);
    if (!copy)
        return NULL;
    PyObject *result = Py_BuildValue("(O(O))", &PyDict_Type, copy);
    Py_DECREF(copy);
    return result;
}
static int memo_traverse(PyObject *op, visitproc visit, void *arg) {
    Py_VISIT(Py_TYPE(op));
    Py_VISIT(((Memo *)op)->owner);
    return 0;
}
static void memo_dealloc(PyObject *op) {
    PyTypeObject *type = Py_TYPE(op);
    PyObject_GC_UnTrack(op);
    Py_XDECREF(((Memo *)op)->owner);
    type->tp_free(op);
    Py_DECREF(type);
}
static PyObject *get_memo(PyObject *op, void *unused) {
    Codec *self = (Codec *)op;
    Module *m = module_for(Py_TYPE(op));
    if (!m)
        return NULL;
    PyTypeObject *type = (PyTypeObject *)(self->reader ? m->unpickler_memo : m->pickler_memo);
    Memo *memo = (Memo *)type->tp_alloc(type, 0);
    if (!memo)
        return NULL;
    memo->owner = (Codec *)Py_NewRef(op);
    return (PyObject *)memo;
}
static int set_memo(PyObject *op, PyObject *value, void *unused) {
    if (!value) {
        PyErr_SetString(PyExc_TypeError, "attribute deletion is not supported");
        return -1;
    }
    Codec *self = (Codec *)op;
    Module *m = module_for(Py_TYPE(op));
    if (!m)
        return -1;
    PyObject *input = Py_NewRef(value);
    if (Py_IS_TYPE(value, (PyTypeObject *)(self->reader ? m->unpickler_memo : m->pickler_memo))) {
        Py_DECREF(input);
        input = memo_copy(value, NULL);
        if (!input)
            return -1;
    }
    int result = (int)(self->reader ? jacpy_unpickler_memo_set(self->native, H(input))
                                    : jacpy_pickler_memo_set(self->native, H(input)));
    Py_DECREF(input);
    return result;
}
static PyObject *clear_memo(PyObject *op, PyObject *unused) {
    jacpy_pickler_memo_clear(((Codec *)op)->native);
    Py_RETURN_NONE;
}
static PyMethodDef pickler_methods[] = {{"dump", pickler_dump, METH_O, NULL},
                                        {"clear_memo", clear_memo, METH_NOARGS, NULL},
                                        {"persistent_id", persistent_id, METH_O, NULL},
                                        {"__sizeof__", codec_sizeof, METH_NOARGS, NULL},
                                        {NULL}};
static PyMethodDef unpickler_methods[] = {{"load", unpickler_load, METH_NOARGS, NULL},
                                          {"find_class", find_class, METH_VARARGS, NULL},
                                          {"persistent_load", persistent_load, METH_O, NULL},
                                          {"__sizeof__", codec_sizeof, METH_NOARGS, NULL},
                                          {NULL}};
static PyMemberDef pickler_members[] = {
    {"bin", Py_T_INT, offsetof(Codec, bin), 0, NULL},
    {"fast", Py_T_INT, offsetof(Codec, fast), 0, NULL},
    {"dispatch_table", Py_T_OBJECT_EX, offsetof(Codec, dispatch), 0, NULL},
    {NULL}};
static PyGetSetDef codec_getsets[] = {{"memo", get_memo, set_memo, NULL, NULL}, {NULL}};
static PyMethodDef memo_methods[] = {{"copy", memo_copy, METH_NOARGS, NULL},
                                     {"clear", memo_clear, METH_NOARGS, NULL},
                                     {"__reduce__", memo_reduce, METH_NOARGS, NULL},
                                     {NULL}};
#define CODEC_SLOTS(INIT, METHODS)                                                                 \
    {Py_tp_new, codec_new}, {Py_tp_init, INIT}, {Py_tp_dealloc, codec_dealloc},                    \
        {Py_tp_traverse, codec_traverse}, {Py_tp_clear, codec_clear},                              \
        {Py_tp_getattro, codec_getattro}, {Py_tp_setattro, codec_setattro},                        \
        {Py_tp_methods, METHODS}, {                                                                \
        Py_tp_getset, codec_getsets                                                                \
    }
static PyType_Slot pickler_slots[] = {
    CODEC_SLOTS(pickler_init, pickler_methods), {Py_tp_members, pickler_members}, {0}};
static PyType_Slot unpickler_slots[] = {CODEC_SLOTS(unpickler_init, unpickler_methods), {0}};
static PyType_Slot memo_slots[] = {{Py_tp_dealloc, memo_dealloc},
                                   {Py_tp_traverse, memo_traverse},
                                   {Py_tp_methods, memo_methods},
                                   {0}};
#define CODEC_FLAGS                                                                                \
    (Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC | Py_TPFLAGS_IMMUTABLETYPE)
static PyType_Spec pickler_spec = {"_pickle.Pickler", sizeof(Codec), 0, CODEC_FLAGS, pickler_slots};
static PyType_Spec unpickler_spec = {"_pickle.Unpickler", sizeof(Codec), 0, CODEC_FLAGS,
                                     unpickler_slots};
static PyType_Spec pickler_memo_spec = {
    "_pickle.PicklerMemoProxy", sizeof(Memo), 0,
    Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC | Py_TPFLAGS_IMMUTABLETYPE, memo_slots};
static PyType_Spec unpickler_memo_spec = {
    "_pickle.UnpicklerMemoProxy", sizeof(Memo), 0,
    Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC | Py_TPFLAGS_IMMUTABLETYPE, memo_slots};
static PyObject *module_dump(PyObject *module, PyObject *args, PyObject *kw) {
    static char *names[] = {"obj", "file", "protocol", "fix_imports", "buffer_callback", NULL};
    PyObject *value, *file, *protocol = Py_None, *callback = Py_None;
    int fix = 1;
    if (!PyArg_ParseTupleAndKeywords(args, kw, "OO|O$pO:dump", names, &value, &file, &protocol,
                                     &fix, &callback))
        return NULL;
    Module *m = PyModule_GetState(module);
    PyObject *parameters = Py_BuildValue("(OO)", file, protocol),
             *keywords = Py_BuildValue("{s:O,s:O}", "fix_imports", fix ? Py_True : Py_False,
                                       "buffer_callback", callback),
             *codec = NULL, *result = NULL;
    if (parameters && keywords)
        codec = PyObject_Call(m->pickler, parameters, keywords);
    if (codec)
        result = pickler_dump(codec, value);
    Py_XDECREF(parameters);
    Py_XDECREF(keywords);
    Py_XDECREF(codec);
    return result;
}
static PyObject *module_dumps(PyObject *module, PyObject *args, PyObject *kw) {
    static char *names[] = {"obj", "protocol", "fix_imports", "buffer_callback", NULL};
    PyObject *value, *protocol = Py_None, *callback = Py_None;
    int fix = 1;
    if (!PyArg_ParseTupleAndKeywords(args, kw, "O|O$pO:dumps", names, &value, &protocol, &fix,
                                     &callback))
        return NULL;
    Module *m = PyModule_GetState(module);
    PyObject *file = PyObject_CallNoArgs(m->bytesio);
    if (!file)
        return NULL;
    PyObject *parameters = Py_BuildValue("(OOO)", value, file, protocol),
             *keywords = Py_BuildValue("{s:O,s:O}", "fix_imports", fix ? Py_True : Py_False,
                                       "buffer_callback", callback),
             *written = NULL, *result = NULL;
    if (parameters && keywords)
        written = module_dump(module, parameters, keywords);
    if (written)
        result = PyObject_CallMethod(file, "getvalue", NULL);
    Py_XDECREF(parameters);
    Py_XDECREF(keywords);
    Py_XDECREF(written);
    Py_DECREF(file);
    return result;
}
static PyObject *module_load(PyObject *module, PyObject *args, PyObject *kw) {
    Module *m = PyModule_GetState(module);
    PyObject *codec = PyObject_Call(m->unpickler, args, kw);
    if (!codec)
        return NULL;
    PyObject *result = unpickler_load(codec, NULL);
    Py_DECREF(codec);
    return result;
}
static PyObject *module_loads(PyObject *module, PyObject *args, PyObject *kw) {
    static char *names[] = {"data", "fix_imports", "encoding", "errors", "buffers", NULL};
    PyObject *data, *buffers = Py_None;
    const char *encoding = "ASCII", *errors = "strict";
    int fix = 1;
    if (!PyArg_ParseTupleAndKeywords(args, kw, "O|$pssO:loads", names, &data, &fix, &encoding,
                                     &errors, &buffers))
        return NULL;
    Module *m = PyModule_GetState(module);
    PyObject *file = PyObject_CallOneArg(m->bytesio, data);
    if (!file)
        return NULL;
    PyObject *parameters = PyTuple_Pack(1, file),
             *keywords = Py_BuildValue("{s:O,s:s,s:s,s:O}", "fix_imports", fix ? Py_True : Py_False,
                                       "encoding", encoding, "errors", errors, "buffers", buffers),
             *result = NULL;
    if (parameters && keywords)
        result = module_load(module, parameters, keywords);
    Py_XDECREF(parameters);
    Py_XDECREF(keywords);
    Py_DECREF(file);
    return result;
}
static PyMethodDef methods[] = {
    {"dump", (PyCFunction)module_dump, METH_VARARGS | METH_KEYWORDS, NULL},
    {"dumps", (PyCFunction)module_dumps, METH_VARARGS | METH_KEYWORDS, NULL},
    {"load", (PyCFunction)module_load, METH_VARARGS | METH_KEYWORDS, NULL},
    {"loads", (PyCFunction)module_loads, METH_VARARGS | METH_KEYWORDS, NULL},
    {NULL}};
static int module_traverse(PyObject *module, visitproc visit, void *arg) {
    Module *m = PyModule_GetState(module);
    Py_VISIT(m->pickler);
    Py_VISIT(m->unpickler);
    Py_VISIT(m->pickler_memo);
    Py_VISIT(m->unpickler_memo);
    Py_VISIT(m->error);
    Py_VISIT(m->pickling_error);
    Py_VISIT(m->unpickling_error);
    Py_VISIT(m->bytesio);
    Py_VISIT(m->dispatch);
    return 0;
}
static int module_clear(PyObject *module) {
    Module *m = PyModule_GetState(module);
    Py_CLEAR(m->pickler);
    Py_CLEAR(m->unpickler);
    Py_CLEAR(m->pickler_memo);
    Py_CLEAR(m->unpickler_memo);
    Py_CLEAR(m->error);
    Py_CLEAR(m->pickling_error);
    Py_CLEAR(m->unpickling_error);
    Py_CLEAR(m->bytesio);
    Py_CLEAR(m->dispatch);
    return 0;
}
static int execute(PyObject *module) {
    Module *m = PyModule_GetState(module);
    m->error = PyErr_NewException("_pickle.PickleError", NULL, NULL);
    if (!m->error)
        return -1;
    m->pickling_error = PyErr_NewException("_pickle.PicklingError", m->error, NULL);
    m->unpickling_error = PyErr_NewException("_pickle.UnpicklingError", m->error, NULL);
    m->pickler = PyType_FromModuleAndSpec(module, &pickler_spec, NULL);
    m->unpickler = PyType_FromModuleAndSpec(module, &unpickler_spec, NULL);
    m->pickler_memo = PyType_FromModuleAndSpec(module, &pickler_memo_spec, NULL);
    m->unpickler_memo = PyType_FromModuleAndSpec(module, &unpickler_memo_spec, NULL);
    m->bytesio = PyImport_ImportModuleAttrString("_io", "BytesIO");
    m->dispatch = PyImport_ImportModuleAttrString("copyreg", "dispatch_table");
    if (!m->pickling_error || !m->unpickling_error || !m->pickler || !m->unpickler ||
        !m->pickler_memo || !m->unpickler_memo || !m->bytesio || !m->dispatch)
        return -1;
    return PyModule_AddObjectRef(module, "PickleError", m->error) < 0 ||
                   PyModule_AddObjectRef(module, "PicklingError", m->pickling_error) < 0 ||
                   PyModule_AddObjectRef(module, "UnpicklingError", m->unpickling_error) < 0 ||
                   PyModule_AddObjectRef(module, "Pickler", m->pickler) < 0 ||
                   PyModule_AddObjectRef(module, "Unpickler", m->unpickler) < 0 ||
                   PyModule_AddObjectRef(module, "PickleBuffer", (PyObject *)&PyPickleBuffer_Type) <
                       0
               ? -1
               : 0;
}
static PyModuleDef_Slot slots[] = {
    {Py_mod_exec, execute},
    {Py_mod_multiple_interpreters, Py_MOD_PER_INTERPRETER_GIL_SUPPORTED},
    {0}};
static PyModuleDef definition = {
    PyModuleDef_HEAD_INIT, "_pickle",    "Native Jac pickle serialization.",
    sizeof(Module),        methods,      slots,
    module_traverse,       module_clear, NULL};
PyMODINIT_FUNC PyInit__pickle(void) { return PyModuleDef_Init(&definition); }
