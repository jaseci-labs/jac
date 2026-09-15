#define PY_SSIZE_T_CLEAN
#include <Python.h>
#include <stdint.h>
#include <unistd.h>
#include <errno.h>
#include "internal/pycore_unicodeobject.h"
#include "internal/pycore_bytesobject.h"
#include "internal/pycore_pyerrors.h"

/* Exception identity belongs to the retained runtime, not the caller's
 * mutable builtins dictionary. Shared by compiler and extension boundaries. */
PyObject *jacpy_exception_type(const char *name) {
#define EXCEPTION(kind) if (strcmp(name, #kind) == 0) return PyExc_##kind
    EXCEPTION(BaseException); EXCEPTION(Exception); EXCEPTION(BaseExceptionGroup);
    EXCEPTION(StopAsyncIteration); EXCEPTION(StopIteration); EXCEPTION(GeneratorExit);
    EXCEPTION(ArithmeticError); EXCEPTION(LookupError); EXCEPTION(AssertionError);
    EXCEPTION(AttributeError); EXCEPTION(BufferError); EXCEPTION(EOFError);
    EXCEPTION(FloatingPointError); EXCEPTION(OSError); EXCEPTION(ImportError);
    EXCEPTION(ModuleNotFoundError); EXCEPTION(IndexError); EXCEPTION(KeyError);
    EXCEPTION(KeyboardInterrupt); EXCEPTION(MemoryError); EXCEPTION(NameError);
    EXCEPTION(OverflowError); EXCEPTION(RuntimeError); EXCEPTION(RecursionError);
    EXCEPTION(NotImplementedError); EXCEPTION(SyntaxError); EXCEPTION(IndentationError);
    EXCEPTION(TabError); EXCEPTION(ReferenceError); EXCEPTION(SystemError);
    EXCEPTION(SystemExit); EXCEPTION(TypeError); EXCEPTION(UnboundLocalError);
    EXCEPTION(UnicodeError); EXCEPTION(UnicodeEncodeError); EXCEPTION(UnicodeDecodeError);
    EXCEPTION(UnicodeTranslateError); EXCEPTION(ValueError); EXCEPTION(ZeroDivisionError);
    EXCEPTION(BlockingIOError); EXCEPTION(BrokenPipeError); EXCEPTION(ChildProcessError);
    EXCEPTION(ConnectionError); EXCEPTION(ConnectionAbortedError); EXCEPTION(ConnectionRefusedError);
    EXCEPTION(ConnectionResetError); EXCEPTION(FileExistsError); EXCEPTION(FileNotFoundError);
    EXCEPTION(InterruptedError); EXCEPTION(IsADirectoryError); EXCEPTION(NotADirectoryError);
    EXCEPTION(PermissionError); EXCEPTION(ProcessLookupError); EXCEPTION(TimeoutError);
    EXCEPTION(EnvironmentError); EXCEPTION(IOError); EXCEPTION(Warning);
    EXCEPTION(UserWarning); EXCEPTION(DeprecationWarning); EXCEPTION(PendingDeprecationWarning);
    EXCEPTION(SyntaxWarning); EXCEPTION(RuntimeWarning); EXCEPTION(FutureWarning);
    EXCEPTION(ImportWarning); EXCEPTION(UnicodeWarning); EXCEPTION(BytesWarning);
    EXCEPTION(EncodingWarning); EXCEPTION(ResourceWarning);
#undef EXCEPTION
    if (strcmp(name, "_IncompleteInputError") == 0) return PyExc_IncompleteInputError;
    return NULL;
}

/* Values returned by this boundary are owned PyBytes handles. Callers hold
 * the GIL, copy the UTF-8 payload into Jac-owned storage, and release them. */
static uint64_t utf8_result(PyObject *value) {
    if (value == NULL) return 0;
    PyObject *bytes = PyUnicode_AsEncodedString(value, "utf-8", "surrogatepass");
    Py_DECREF(value);
    return (uint64_t)(uintptr_t)bytes;
}
uint64_t jacpy_normalize(const char *source, int64_t size) {
    PyObject *text = PyUnicode_DecodeUTF8(source, size, "surrogatepass");
    if (text == NULL) return 0;
    PyObject *module = PyImport_ImportModule("unicodedata");
    if (module == NULL) { Py_DECREF(text); return 0; }
    PyObject *result = PyObject_CallMethod(module, "normalize", "sO", "NFKC", text);
    Py_DECREF(module);
    Py_DECREF(text);
    return utf8_result(result);
}
uint64_t jacpy_unicode_escape(const char *source, int64_t size) {
    const char *invalid = NULL;
    int invalid_char = -1;
    return utf8_result(_PyUnicode_DecodeUnicodeEscapeInternal2(source, size, NULL, NULL, &invalid_char, &invalid));
}
uint64_t jacpy_bytes_escape(const char *source, int64_t size) {
    const char *invalid = NULL;
    int invalid_char = -1;
    return (uint64_t)(uintptr_t)_PyBytes_DecodeEscape2(source, size, NULL, &invalid_char, &invalid);
}
int64_t jacpy_buffer_size(uint64_t handle) { return PyBytes_GET_SIZE((PyObject *)(uintptr_t)handle); }
int64_t jacpy_buffer_byte(uint64_t handle, int64_t index) {
    return (unsigned char)PyBytes_AS_STRING((PyObject *)(uintptr_t)handle)[index];
}
void jacpy_release(uint64_t handle) { Py_XDECREF((PyObject *)(uintptr_t)handle); }
int64_t jacpy_warning(const char *message, const char *filename, int64_t line) {
    return PyErr_WarnExplicit(PyExc_SyntaxWarning, message, filename, (int)line, NULL, NULL);
}

/* Numeric conversion is retained object-runtime behavior. The Jac parser
 * classifies literals and the native compiler owns their serialized values. */
#include "marshal.h"
uint64_t jacpy_parse_long(const char *source, int64_t size) {
    PyObject *text = PyUnicode_DecodeUTF8(source, size, "strict");
    if (text == NULL) return 0;
    PyObject *value = PyLong_FromUnicodeObject(text, 0);
    Py_DECREF(text);
    if (value == NULL) return 0;
    PyObject *data = PyMarshal_WriteObjectToString(value, 4);
    Py_DECREF(value);
    return (uint64_t)(uintptr_t)data;
}
uint64_t jacpy_parse_float(const char *source, int64_t size) {
    PyObject *text = PyUnicode_DecodeUTF8(source, size, "strict");
    if (text == NULL) return 0;
    PyObject *value = PyFloat_FromString(text);
    Py_DECREF(text);
    return (uint64_t)(uintptr_t)value;
}
double jacpy_float_value(uint64_t handle) { return PyFloat_AS_DOUBLE((PyObject *)(uintptr_t)handle); }

/* AST constructors and attributes are retained CPython value operations.
 * Traversal, node selection, and field conversion live in native Jac. */
uint64_t jacpy_ast_new(const char *name) {
    PyObject *module = PyImport_ImportModule("_ast");
    if (module == NULL) return 0;
    PyObject *type = PyObject_GetAttrString(module, name);
    Py_DECREF(module);
    if (type == NULL) return 0;
    /* All fields are filled by Jac before publication; invoking __init__
     * here would warn about fields that have not yet crossed the boundary. */
    if (!PyType_Check(type)) {
        Py_DECREF(type);
        PyErr_SetString(PyExc_TypeError, "invalid retained AST type");
        return 0;
    }
    PyObject *result = PyType_GenericAlloc((PyTypeObject *)type, 0);
    Py_DECREF(type);
    return (uint64_t)(uintptr_t)result;
}
int64_t jacpy_set_owned(uint64_t target, const char *name, uint64_t value) {
    if (!value) return -1;
    PyObject *item = (PyObject *)(uintptr_t)value;
    int status = PyObject_SetAttrString((PyObject *)(uintptr_t)target, name, item);
    Py_DECREF(item);
    return status;
}
uint64_t jacpy_list_new(void) { return (uint64_t)(uintptr_t)PyList_New(0); }
int64_t jacpy_list_append_owned(uint64_t target, uint64_t value) {
    if (!value) return -1;
    PyObject *item = (PyObject *)(uintptr_t)value;
    int status = PyList_Append((PyObject *)(uintptr_t)target, item);
    Py_DECREF(item);
    return status;
}
uint64_t jacpy_none(void) { return (uint64_t)(uintptr_t)Py_NewRef(Py_None); }
uint64_t jacpy_int(int64_t value) { return (uint64_t)(uintptr_t)PyLong_FromLongLong(value); }
uint64_t jacpy_text(const char *value, int64_t size) {
    return (uint64_t)(uintptr_t)PyUnicode_DecodeUTF8(value, size, "surrogatepass");
}
uint64_t jacpy_buffer_new(int64_t size) { return (uint64_t)(uintptr_t)PyBytes_FromStringAndSize(NULL, size); }
void jacpy_buffer_set(uint64_t handle, int64_t index, int64_t value) {
    PyBytes_AS_STRING((PyObject *)(uintptr_t)handle)[index] = (char)value;
}
uint64_t jacpy_unmarshal(uint64_t handle) {
    PyObject *bytes = (PyObject *)(uintptr_t)handle;
    return (uint64_t)(uintptr_t)PyMarshal_ReadObjectFromString(PyBytes_AS_STRING(bytes), PyBytes_GET_SIZE(bytes));
}

int64_t jacpy_value_kind(uint64_t handle) {
    PyObject *value = (PyObject *)(uintptr_t)handle;
    if (value == Py_None) return 0;
    if (value == Py_Ellipsis) return 1;
    if (PyBool_Check(value)) return 2;
    if (PyLong_Check(value)) return 3;
    if (PyFloat_Check(value)) return 4;
    if (PyComplex_Check(value)) return 5;
    if (PyUnicode_Check(value)) return 6;
    if (PyBytes_Check(value)) return 7;
    if (PyTuple_Check(value)) return 8;
    if (PyFrozenSet_Check(value)) return 9;
    return -1;
}
int64_t jacpy_truth(uint64_t handle) { return PyObject_IsTrue((PyObject *)(uintptr_t)handle); }
uint64_t jacpy_marshal(uint64_t handle) {
    return (uint64_t)(uintptr_t)PyMarshal_WriteObjectToString((PyObject *)(uintptr_t)handle, 4);
}
uint64_t jacpy_utf8(uint64_t handle) {
    return (uint64_t)(uintptr_t)PyUnicode_AsEncodedString((PyObject *)(uintptr_t)handle,"utf-8","surrogatepass");
}
uint64_t jacpy_bytes_copy(uint64_t handle) { return (uint64_t)(uintptr_t)Py_NewRef((PyObject *)(uintptr_t)handle); }
double jacpy_real(uint64_t handle) { return PyComplex_RealAsDouble((PyObject *)(uintptr_t)handle); }
double jacpy_imag(uint64_t handle) { return PyComplex_ImagAsDouble((PyObject *)(uintptr_t)handle); }
uint64_t jacpy_sequence(uint64_t handle) { return (uint64_t)(uintptr_t)PySequence_List((PyObject *)(uintptr_t)handle); }
int64_t jacpy_sequence_size(uint64_t handle) { return PyList_GET_SIZE((PyObject *)(uintptr_t)handle); }
uint64_t jacpy_sequence_item(uint64_t handle, int64_t index) {
    return (uint64_t)(uintptr_t)Py_NewRef(PyList_GET_ITEM((PyObject *)(uintptr_t)handle,index));
}
uint64_t jacpy_field(uint64_t handle, const char *name) {
    PyObject *value = NULL;
    if (PyObject_GetOptionalAttrString((PyObject *)(uintptr_t)handle,name,&value) < 0) return 0;
    if (value == NULL) PyErr_Format(PyExc_TypeError,"required field \"%s\" missing from %s",name,Py_TYPE((PyObject *)(uintptr_t)handle)->tp_name);
    return (uint64_t)(uintptr_t)value;
}
uint64_t jacpy_optional_field(uint64_t handle, const char *name) {
    PyObject *value = NULL;
    if (PyObject_GetOptionalAttrString((PyObject *)(uintptr_t)handle,name,&value) < 0) return 0;
    return (uint64_t)(uintptr_t)(value != NULL ? value : Py_NewRef(Py_None));
}
int64_t jacpy_ast_is(uint64_t handle, const char *name) {
    PyObject *module = PyImport_ImportModule("_ast");
    if (module == NULL) return -1;
    PyObject *type = PyObject_GetAttrString(module,name);
    Py_DECREF(module);
    if (type == NULL) return -1;
    int result = PyObject_IsInstance((PyObject *)(uintptr_t)handle,type);
    Py_DECREF(type);
    return result;
}
int64_t jacpy_is_list(uint64_t handle) { return PyList_Check((PyObject *)(uintptr_t)handle); }
int64_t jacpy_integer_value(uint64_t handle) { return PyLong_AsLongLong((PyObject *)(uintptr_t)handle); }
int64_t jacpy_error_pending(void) { return PyErr_Occurred() != NULL; }

uint64_t jacpy_decode(uint64_t handle, const char *encoding) {
    PyObject *data = (PyObject *)(uintptr_t)handle;
    return utf8_result(PyUnicode_Decode(PyBytes_AS_STRING(data),PyBytes_GET_SIZE(data),encoding,"strict"));
}
uint64_t jacpy_take_error_text(void) {
    PyObject *error = PyErr_GetRaisedException();
    if (error == NULL) { PyErr_SetString(PyExc_SystemError,"missing boundary exception"); return 0; }
    PyObject *text = PyObject_Str(error);
    Py_DECREF(error);
    return utf8_result(text);
}
int64_t jacpy_error_is(const char *name) {
    PyObject *type = jacpy_exception_type(name);
    return type != NULL && PyErr_ExceptionMatches(type);
}

#include <structmember.h>
typedef struct {
    PyObject_HEAD
    PyObject *name, *symbols, *varnames, *children;
    int type, lineno, nested;
} JacSymtableEntry;
static int jac_entry_traverse(PyObject *object, visitproc visit, void *arg) {
    JacSymtableEntry *entry=(JacSymtableEntry *)object;
    Py_VISIT(Py_TYPE(object)); Py_VISIT(entry->name); Py_VISIT(entry->symbols);
    Py_VISIT(entry->varnames); Py_VISIT(entry->children);
    return 0;
}
static int jac_entry_clear(PyObject *object) {
    JacSymtableEntry *entry=(JacSymtableEntry *)object;
    Py_CLEAR(entry->name); Py_CLEAR(entry->symbols); Py_CLEAR(entry->varnames); Py_CLEAR(entry->children);
    return 0;
}
static void jac_entry_dealloc(PyObject *object) {
    PyTypeObject *type=Py_TYPE(object);
    PyObject_GC_UnTrack(object); jac_entry_clear(object); type->tp_free(object); Py_DECREF(type);
}
static PyObject *jac_entry_id(PyObject *object, void *closure) { return PyLong_FromVoidPtr(object); }
static PyObject *jac_entry_repr(PyObject *object) {
    JacSymtableEntry *entry=(JacSymtableEntry *)object;
    return PyUnicode_FromFormat("<symtable entry %U(%llu), line %d>",entry->name,(unsigned long long)(uintptr_t)object,entry->lineno);
}
static PyMemberDef jac_entry_members[] = {
    {"name",T_OBJECT_EX,offsetof(JacSymtableEntry,name),READONLY,NULL},
    {"symbols",T_OBJECT_EX,offsetof(JacSymtableEntry,symbols),READONLY,NULL},
    {"varnames",T_OBJECT_EX,offsetof(JacSymtableEntry,varnames),READONLY,NULL},
    {"children",T_OBJECT_EX,offsetof(JacSymtableEntry,children),READONLY,NULL},
    {"type",T_INT,offsetof(JacSymtableEntry,type),READONLY,NULL},
    {"lineno",T_INT,offsetof(JacSymtableEntry,lineno),READONLY,NULL},
    {"nested",T_INT,offsetof(JacSymtableEntry,nested),READONLY,NULL},
    {NULL}
};
static PyGetSetDef jac_entry_getsets[] = {{"id",jac_entry_id,NULL,NULL,NULL},{NULL}};
static PyType_Slot jac_entry_slots[] = {
    {Py_tp_dealloc,jac_entry_dealloc}, {Py_tp_traverse,jac_entry_traverse},
    {Py_tp_clear,jac_entry_clear}, {Py_tp_repr,jac_entry_repr},
    {Py_tp_members,jac_entry_members}, {Py_tp_getset,jac_entry_getsets}, {0,NULL}
};
static PyType_Spec jac_entry_spec = {
    .name="_symtable.SymtableEntry",.basicsize=sizeof(JacSymtableEntry),
    .flags=Py_TPFLAGS_DEFAULT|Py_TPFLAGS_HAVE_GC,.slots=jac_entry_slots
};
uint64_t jacpy_symtable_entry(uint64_t name, int64_t kind, int64_t lineno, int64_t nested,
                            uint64_t symbols, uint64_t varnames, uint64_t children) {
    PyObject *state=PyInterpreterState_GetDict(PyInterpreterState_Get());
    if (state == NULL) return 0;
    PyObject *type=PyDict_GetItemString(state,"_jacpython_symtable_type");
    if (type == NULL) {
        type=PyType_FromSpec(&jac_entry_spec);
        if (type == NULL) return 0;
        int status=PyDict_SetItemString(state,"_jacpython_symtable_type",type);
        Py_DECREF(type);
        if (status < 0) return 0;
        type=PyDict_GetItemString(state,"_jacpython_symtable_type");
    }
    JacSymtableEntry *entry=(JacSymtableEntry *)PyType_GenericAlloc((PyTypeObject *)type,0);
    if (entry == NULL) return 0;
    entry->name=Py_NewRef((PyObject *)(uintptr_t)name);
    entry->symbols=Py_NewRef((PyObject *)(uintptr_t)symbols);
    entry->varnames=Py_NewRef((PyObject *)(uintptr_t)varnames);
    entry->children=Py_NewRef((PyObject *)(uintptr_t)children);
    entry->type=(int)kind; entry->lineno=(int)lineno; entry->nested=(int)nested;
    return (uint64_t)(uintptr_t)entry;
}
uint64_t jacpy_dict_new(void) { return (uint64_t)(uintptr_t)PyDict_New(); }
int64_t jacpy_dict_set_owned(uint64_t dictionary,uint64_t key,uint64_t value) {
    PyObject *k=(PyObject *)(uintptr_t)key,*v=(PyObject *)(uintptr_t)value;
    if (k == NULL || v == NULL) { Py_XDECREF(k); Py_XDECREF(v); return -1; }
    int status=PyDict_SetItem((PyObject *)(uintptr_t)dictionary,k,v);
    Py_DECREF(k); Py_DECREF(v); return status;
}
/* Calling the user's readline function is an input boundary; tokenization
 * and stream state are native Jac. Return owned UTF-8 bytes. */
uint64_t jacpy_readline(uint64_t reader, const char *encoding, int64_t decode) {
    PyObject *line=PyObject_CallNoArgs((PyObject *)(uintptr_t)reader);
    if (line == NULL) {
        if (!PyErr_ExceptionMatches(PyExc_StopIteration)) return 0;
        PyErr_Clear(); return (uint64_t)(uintptr_t)PyBytes_FromStringAndSize("",0);
    }
    if (decode) {
        if (!PyBytes_Check(line)) {
            Py_DECREF(line); PyErr_SetString(PyExc_TypeError,"readline() returned a non-bytes object"); return 0;
        }
        PyObject *text=PyUnicode_Decode(PyBytes_AS_STRING(line),PyBytes_GET_SIZE(line),encoding,"replace");
        Py_DECREF(line); line=text;
    } else if (!PyUnicode_Check(line)) {
        Py_DECREF(line); PyErr_SetString(PyExc_TypeError,"readline() returned a non-string"); return 0;
    }
    return utf8_result(line);
}
uint64_t jacpy_source_bytes(uint64_t handle) {
    Py_buffer view;
    if (PyObject_GetBuffer((PyObject *)(uintptr_t)handle,&view,PyBUF_SIMPLE) < 0) return 0;
    PyObject *copy=PyBytes_FromStringAndSize(view.buf,view.len);
    PyBuffer_Release(&view);
    return (uint64_t)(uintptr_t)copy;
}
int64_t jacpy_source_kind(uint64_t handle) {
    PyObject *value=(PyObject *)(uintptr_t)handle;
    if (PyUnicode_Check(value)) return 0;
    if (PyObject_CheckBuffer(value)) return 1;
    int64_t is_ast=jacpy_ast_is(handle,"AST");
    return is_ast > 0 ? 2 : -1;
}
int64_t jacpy_codec_valid(const char *name) {
    PyObject *codec=PyCodec_Encoder(name);
    if (codec == NULL) return 0;
    Py_DECREF(codec); return 1;
}
uint64_t jacpy_fd_line(int64_t fd) {
    PyObject *line=PyByteArray_FromStringAndSize(NULL,0);
    if (!line) return 0;
    for (;;) {
        char ch; ssize_t count=read((int)fd,&ch,1);
        if (count < 0) { if (errno == EINTR) { if (PyErr_CheckSignals() < 0) { Py_DECREF(line); return 0; } continue; } Py_DECREF(line); PyErr_SetFromErrno(PyExc_OSError); return 0; }
        if (!count) break;
        Py_ssize_t length=PyByteArray_GET_SIZE(line);
        if (PyByteArray_Resize(line,length+1) < 0) { Py_DECREF(line); return 0; }
        PyByteArray_AS_STRING(line)[length]=ch;
        if (ch == '\n') break;
    }
    PyObject *result=PyBytes_FromObject(line); Py_DECREF(line);
    return (uint64_t)(uintptr_t)result;
}
void jacpy_raise_error(const char *kind, const char *message, int64_t size) {
    PyObject *type=jacpy_exception_type(kind);
    if (type == NULL) type=PyExc_SystemError;
    PyObject *text=PyUnicode_DecodeUTF8(message,size,"surrogatepass");
    if (text) { PyErr_SetObject(type,text); Py_DECREF(text); }
}

/* Initialize Jac native module storage before CPython starts importing. */
extern void __jac_shared_init(void);
__attribute__((constructor)) static void jacpy_initialize(void) { __jac_shared_init(); }
