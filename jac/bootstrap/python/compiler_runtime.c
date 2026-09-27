#define PY_SSIZE_T_CLEAN
#include <Python.h>
#include <stdint.h>
#include <unistd.h>
#include <errno.h>
#include "internal/pycore_unicodeobject.h"
#include "internal/pycore_bytesobject.h"
#include "internal/pycore_pyerrors.h"
#include "internal/pycore_ast.h"
#include "internal/pycore_ast_state.h"
#include "internal/pycore_pystate.h"
#include "internal/pycore_code.h"

/* libpython is built with hidden visibility, so only marked symbols reach a
 * native library that dlopens into this runtime. These entry points ARE that
 * boundary -- a separately built native unit calls them -- so export them. */
#pragma GCC visibility push(default)


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
static PyObject *utf8_result(PyObject *value) {
    if (value == NULL) return NULL;
    PyObject *bytes = PyUnicode_AsEncodedString(value, "utf-8", "surrogatepass");
    Py_DECREF(value);
    return bytes;
}
PyObject *jacpy_normalize(const char *source, int64_t size) {
    PyObject *text = PyUnicode_DecodeUTF8(source, size, "surrogatepass");
    if (text == NULL) return NULL;
    PyObject *module = PyImport_ImportModule("unicodedata");
    if (module == NULL) { Py_DECREF(text); return NULL; }
    PyObject *result = PyObject_CallMethod(module, "normalize", "sO", "NFKC", text);
    Py_DECREF(module);
    Py_DECREF(text);
    return utf8_result(result);
}
PyObject *jacpy_unicode_escape(const char *source, int64_t size) {
    const char *invalid = NULL;
    int invalid_char = -1;
    return utf8_result(_PyUnicode_DecodeUnicodeEscapeInternal2(source, size, NULL, NULL, &invalid_char, &invalid));
}
PyObject *jacpy_bytes_escape(const char *source, int64_t size) {
    const char *invalid = NULL;
    int invalid_char = -1;
    return _PyBytes_DecodeEscape2(source, size, NULL, &invalid_char, &invalid);
}
int64_t jacpy_buffer_size(PyObject *handle) { return PyBytes_GET_SIZE(handle); }
int64_t jacpy_buffer_byte(PyObject *handle, int64_t index) {
    return (unsigned char)PyBytes_AS_STRING(handle)[index];
}
void jacpy_release(PyObject *handle) { Py_XDECREF(handle); }
int64_t jacpy_warning(const char *message, const char *filename, int64_t line) {
    return PyErr_WarnExplicit(PyExc_SyntaxWarning, message, filename, (int)line, NULL, NULL);
}

/* Numeric conversion is retained object-runtime behavior. The Jac parser
 * classifies literals and the native compiler owns their serialized values. */
#include "marshal.h"
PyObject *jacpy_parse_long(const char *source, int64_t size) {
    PyObject *text = PyUnicode_DecodeUTF8(source, size, "strict");
    if (text == NULL) return NULL;
    PyObject *value = PyLong_FromUnicodeObject(text, 0);
    Py_DECREF(text);
    if (value == NULL) return NULL;
    PyObject *data = PyMarshal_WriteObjectToString(value, 4);
    Py_DECREF(value);
    return data;
}
PyObject *jacpy_parse_float(const char *source, int64_t size) {
    PyObject *text = PyUnicode_DecodeUTF8(source, size, "strict");
    if (text == NULL) return NULL;
    PyObject *value = PyFloat_FromString(text);
    Py_DECREF(text);
    return value;
}
double jacpy_float_value(PyObject *handle) { return PyFloat_AS_DOUBLE(handle); }

/* AST constructors and attributes are retained CPython value operations.
 * Traversal, node selection, and field conversion live in native Jac.
 * Kinds are numbered in the order of `ast_kind`
 * (jaclang/compiler/frontend/python/ast_nodes.jac); types and the shared
 * context/operator singletons come from the interpreter's AST state, as in
 * CPython's own ast2obj/obj2ast. */
#define JAC_AST_KINDS(NODE, SINGLETON) \
    NODE(Module) NODE(Interactive) NODE(Expression) NODE(FunctionType) \
    NODE(FunctionDef) NODE(AsyncFunctionDef) NODE(ClassDef) NODE(Return) \
    NODE(Delete) NODE(Assign) NODE(TypeAlias) NODE(AugAssign) NODE(AnnAssign) \
    NODE(For) NODE(AsyncFor) NODE(While) NODE(If) NODE(With) NODE(AsyncWith) \
    NODE(Match) NODE(Raise) NODE(Try) NODE(TryStar) NODE(Assert) NODE(Import) \
    NODE(ImportFrom) NODE(Global) NODE(Nonlocal) NODE(Expr) NODE(Pass) NODE(Break) \
    NODE(Continue) NODE(BoolOp) NODE(NamedExpr) NODE(BinOp) NODE(UnaryOp) \
    NODE(Lambda) NODE(IfExp) NODE(Dict) NODE(Set) NODE(ListComp) NODE(SetComp) \
    NODE(DictComp) NODE(GeneratorExp) NODE(Await) NODE(Yield) NODE(YieldFrom) \
    NODE(Compare) NODE(Call) NODE(FormattedValue) NODE(Interpolation) \
    NODE(JoinedStr) NODE(TemplateStr) NODE(Constant) NODE(Attribute) NODE(Subscript) \
    NODE(Starred) NODE(Name) NODE(List) NODE(Tuple) NODE(Slice) SINGLETON(Load) \
    SINGLETON(Store) SINGLETON(Del) SINGLETON(And) SINGLETON(Or) SINGLETON(Add) \
    SINGLETON(Sub) SINGLETON(Mult) SINGLETON(MatMult) SINGLETON(Div) SINGLETON(Mod) \
    SINGLETON(Pow) SINGLETON(LShift) SINGLETON(RShift) SINGLETON(BitOr) \
    SINGLETON(BitXor) SINGLETON(BitAnd) SINGLETON(FloorDiv) SINGLETON(Invert) \
    SINGLETON(Not) SINGLETON(UAdd) SINGLETON(USub) SINGLETON(Eq) SINGLETON(NotEq) \
    SINGLETON(Lt) SINGLETON(LtE) SINGLETON(Gt) SINGLETON(GtE) SINGLETON(Is) \
    SINGLETON(IsNot) SINGLETON(In) SINGLETON(NotIn) NODE(comprehension) \
    NODE(ExceptHandler) NODE(arguments) NODE(arg) NODE(keyword) NODE(alias) \
    NODE(withitem) NODE(match_case) NODE(MatchValue) NODE(MatchSingleton) \
    NODE(MatchSequence) NODE(MatchMapping) NODE(MatchClass) NODE(MatchStar) \
    NODE(MatchAs) NODE(MatchOr) NODE(TypeIgnore) NODE(TypeVar) NODE(ParamSpec) \
    NODE(TypeVarTuple)

typedef struct { ptrdiff_t type; ptrdiff_t singleton; } jac_ast_kind_slots;
#define JAC_AST_NODE(name) {offsetof(struct ast_state, name##_type), -1},
#define JAC_AST_SINGLETON(name) \
    {offsetof(struct ast_state, name##_type), offsetof(struct ast_state, name##_singleton)},
static const jac_ast_kind_slots jac_ast_kinds[] = {JAC_AST_KINDS(JAC_AST_NODE, JAC_AST_SINGLETON)};
#undef JAC_AST_NODE
#undef JAC_AST_SINGLETON
#define JAC_AST_KIND_COUNT ((int64_t)(sizeof(jac_ast_kinds) / sizeof(jac_ast_kinds[0])))

static struct ast_state *jac_ast_state(void) {
    /* PyAST_Check initializes the interpreter's AST types on first use. */
    if (PyAST_Check(Py_None) < 0) return NULL;
    return &_PyInterpreterState_GET()->ast;
}
static PyObject *jac_ast_slot(struct ast_state *state, ptrdiff_t offset) {
    return *(PyObject **)((char *)state + offset);
}
/* Exact types resolve by identity; subclasses take the first kind in
 * declaration order, like obj2ast's isinstance chain. -1: not a concrete
 * node, -2: the AST state could not be initialized. */
int64_t jacpy_ast_kind(PyObject *handle) {
    struct ast_state *state = jac_ast_state();
    if (state == NULL) return -2;
    PyTypeObject *type = Py_TYPE(handle);
    for (int64_t kind = 0; kind < JAC_AST_KIND_COUNT; kind++) {
        if ((PyObject *)type == jac_ast_slot(state, jac_ast_kinds[kind].type)) return kind;
    }
    for (int64_t kind = 0; kind < JAC_AST_KIND_COUNT; kind++) {
        if (PyType_IsSubtype(type, (PyTypeObject *)jac_ast_slot(state, jac_ast_kinds[kind].type))) return kind;
    }
    return -1;
}
PyObject *jacpy_ast_new(int64_t kind) {
    struct ast_state *state = jac_ast_state();
    if (state == NULL) return NULL;
    if (jac_ast_kinds[kind].singleton >= 0)
        return Py_NewRef(jac_ast_slot(state, jac_ast_kinds[kind].singleton));
    /* All fields are filled by Jac before publication; invoking __init__
     * here would warn about fields that have not yet crossed the boundary. */
    PyTypeObject *type = (PyTypeObject *)jac_ast_slot(state, jac_ast_kinds[kind].type);
    return PyType_GenericAlloc(type, 0);
}
/* Field names are the interned identifiers of the same AST state, numbered in
 * the order of `ast_field` (jaclang/compiler/frontend/python/ast_nodes.jac). */
#define JAC_AST_FIELDS(FIELD) \
    FIELD(annotation) FIELD(arg) FIELD(args) FIELD(argtypes) FIELD(asname) \
    FIELD(attr) FIELD(bases) FIELD(body) FIELD(bound) FIELD(cases) FIELD(cause) \
    FIELD(cls) FIELD(col_offset) FIELD(comparators) FIELD(context_expr) \
    FIELD(conversion) FIELD(ctx) FIELD(decorator_list) FIELD(default_value) \
    FIELD(defaults) FIELD(elt) FIELD(elts) FIELD(end_col_offset) FIELD(end_lineno) \
    FIELD(exc) FIELD(finalbody) FIELD(format_spec) FIELD(func) FIELD(generators) \
    FIELD(guard) FIELD(handlers) FIELD(id) FIELD(ifs) FIELD(is_async) FIELD(items) \
    FIELD(iter) FIELD(key) FIELD(keys) FIELD(keywords) FIELD(kind) \
    FIELD(kw_defaults) FIELD(kwarg) FIELD(kwd_attrs) FIELD(kwd_patterns) \
    FIELD(kwonlyargs) FIELD(left) FIELD(level) FIELD(lineno) FIELD(lower) \
    FIELD(module) FIELD(msg) FIELD(name) FIELD(names) FIELD(op) FIELD(operand) \
    FIELD(ops) FIELD(optional_vars) FIELD(orelse) FIELD(pattern) FIELD(patterns) \
    FIELD(posonlyargs) FIELD(rest) FIELD(returns) FIELD(right) FIELD(simple) \
    FIELD(slice) FIELD(step) FIELD(str) FIELD(subject) FIELD(tag) FIELD(target) \
    FIELD(targets) FIELD(test) FIELD(type) FIELD(type_comment) FIELD(type_ignores) \
    FIELD(type_params) FIELD(upper) FIELD(value) FIELD(values) FIELD(vararg)

#define JAC_AST_FIELD(name) offsetof(struct ast_state, name),
static const ptrdiff_t jac_ast_fields[] = {JAC_AST_FIELDS(JAC_AST_FIELD)};
#undef JAC_AST_FIELD

static PyObject *jac_ast_field_name(int64_t field) {
    struct ast_state *state = jac_ast_state();
    return state == NULL ? NULL : jac_ast_slot(state, jac_ast_fields[field]);
}
int64_t jacpy_set_owned(PyObject *target, int64_t field, PyObject *value) {
    if (!value) return -1;
    PyObject *item = value;
    PyObject *name = jac_ast_field_name(field);
    int status = name == NULL ? -1 : PyObject_SetAttr(target, name, item);
    Py_DECREF(item);
    return status;
}
PyObject *jacpy_field(PyObject *handle, int64_t field) {
    PyObject *name = jac_ast_field_name(field);
    PyObject *value = NULL;
    if (name == NULL || PyObject_GetOptionalAttr(handle, name, &value) < 0) return NULL;
    if (value == NULL)
        PyErr_Format(PyExc_TypeError, "required field \"%U\" missing from %s", name,
                     Py_TYPE(handle)->tp_name);
    return value;
}
PyObject *jacpy_optional_field(PyObject *handle, int64_t field) {
    PyObject *name = jac_ast_field_name(field);
    PyObject *value = NULL;
    if (name == NULL || PyObject_GetOptionalAttr(handle, name, &value) < 0) return NULL;
    return (value != NULL ? value : Py_NewRef(Py_None));
}
PyObject *jacpy_list_new(void) { return PyList_New(0); }
int64_t jacpy_list_append_owned(PyObject *target, PyObject *value) {
    if (!value) return -1;
    PyObject *item = value;
    int status = PyList_Append(target, item);
    Py_DECREF(item);
    return status;
}
PyObject *jacpy_none(void) { return Py_NewRef(Py_None); }
PyObject *jacpy_text(const char *value, int64_t size) {
    return PyUnicode_DecodeUTF8(value, size, "surrogatepass");
}
PyObject *jacpy_buffer_new(int64_t size) { return PyBytes_FromStringAndSize(NULL, size); }
void jacpy_buffer_set(PyObject *handle, int64_t index, int64_t value) {
    PyBytes_AS_STRING(handle)[index] = (char)value;
}
/* Code objects are assembled by native Jac and constructed through the same
 * validated constructor marshal uses. Handles are borrowed. */
PyObject *jacpy_code_new(int64_t argcount, int64_t posonlyargcount, int64_t kwonlyargcount, int64_t stacksize, int64_t flags, PyObject *code, PyObject *consts, PyObject *names, PyObject *localsplusnames, PyObject *localspluskinds, PyObject *filename, PyObject *name, PyObject *qualname, int64_t firstlineno, PyObject *linetable, PyObject *exceptiontable) {
    struct _PyCodeConstructor con = {
        .filename = filename,
        .name = name,
        .qualname = qualname,
        .flags = (int)flags,
        .code = code,
        .firstlineno = (int)firstlineno,
        .linetable = linetable,
        .consts = consts,
        .names = names,
        .localsplusnames = localsplusnames,
        .localspluskinds = localspluskinds,
        .argcount = (int)argcount,
        .posonlyargcount = (int)posonlyargcount,
        .kwonlyargcount = (int)kwonlyargcount,
        .stacksize = (int)stacksize,
        .exceptiontable = exceptiontable,
    };
    if (_PyCode_Validate(&con) < 0) return NULL;
    return (PyObject *)_PyCode_New(&con);
}

int64_t jacpy_value_kind(PyObject *handle) {
    PyObject *value = handle;
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
PyObject *jacpy_marshal(PyObject *handle) {
    return PyMarshal_WriteObjectToString(handle, 4);
}
PyObject *jacpy_utf8(PyObject *handle) {
    return PyUnicode_AsEncodedString(handle,"utf-8","surrogatepass");
}
int64_t jacpy_sequence_size(PyObject *handle) { return PyList_GET_SIZE(handle); }
PyObject *jacpy_sequence_item(PyObject *handle, int64_t index) {
    return Py_NewRef(PyList_GET_ITEM(handle,index));
}
int64_t jacpy_is_list(PyObject *handle) { return PyList_Check(handle); }
int64_t jacpy_error_pending(void) { return PyErr_Occurred() != NULL; }

PyObject *jacpy_decode(PyObject *handle, const char *encoding) {
    PyObject *data = handle;
    return utf8_result(PyUnicode_Decode(PyBytes_AS_STRING(data),PyBytes_GET_SIZE(data),encoding,"strict"));
}
PyObject *jacpy_take_error_text(void) {
    PyObject *error = PyErr_GetRaisedException();
    if (error == NULL) { PyErr_SetString(PyExc_SystemError,"missing boundary exception"); return NULL; }
    PyObject *text = PyObject_Str(error);
    Py_DECREF(error);
    return utf8_result(text);
}
/* Compiler failures keep CPython's argument shape: SyntaxError subclasses take
 * (message, (filename, lineno, offset, text, end_lineno, end_offset)). */
void jacpy_raise_compiler_error(const char *kind, PyObject *message, PyObject *location) {
    PyObject *type = jacpy_exception_type(kind);
    if (type == NULL) {
        PyErr_Format(PyExc_SystemError, "unknown native diagnostic %s", kind);
        return;
    }
    if (location != 0 && PyObject_IsSubclass(type, PyExc_SyntaxError) > 0) {
        PyObject *args = PyTuple_Pack(2, message, location);
        if (args != NULL) { PyErr_SetObject(type, args); Py_DECREF(args); }
        return;
    }
    PyErr_SetObject(type, message);
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
PyObject *jacpy_symtable_entry(PyObject *name, int64_t kind, int64_t lineno, int64_t nested, PyObject *symbols, PyObject *varnames, PyObject *children) {
    PyObject *state=PyInterpreterState_GetDict(PyInterpreterState_Get());
    if (state == NULL) return NULL;
    PyObject *type=PyDict_GetItemString(state,"_jacpython_symtable_type");
    if (type == NULL) {
        type=PyType_FromSpec(&jac_entry_spec);
        if (type == NULL) return NULL;
        int status=PyDict_SetItemString(state,"_jacpython_symtable_type",type);
        Py_DECREF(type);
        if (status < 0) return NULL;
        type=PyDict_GetItemString(state,"_jacpython_symtable_type");
    }
    JacSymtableEntry *entry=(JacSymtableEntry *)PyType_GenericAlloc((PyTypeObject *)type,0);
    if (entry == NULL) return NULL;
    entry->name=Py_NewRef(name);
    entry->symbols=Py_NewRef(symbols);
    entry->varnames=Py_NewRef(varnames);
    entry->children=Py_NewRef(children);
    entry->type=(int)kind; entry->lineno=(int)lineno; entry->nested=(int)nested;
    return (PyObject *)entry;
}
int64_t jacpy_dict_set_owned(PyObject *dictionary, PyObject *key, PyObject *value) {
    PyObject *k=key,*v=value;
    if (k == NULL || v == NULL) { Py_XDECREF(k); Py_XDECREF(v); return -1; }
    int status=PyDict_SetItem(dictionary,k,v);
    Py_DECREF(k); Py_DECREF(v); return status;
}
/* Calling the user's readline function is an input boundary; tokenization
 * and stream state are native Jac. Return owned UTF-8 bytes. */
PyObject *jacpy_readline(PyObject *reader, const char *encoding, int64_t decode) {
    PyObject *line=PyObject_CallNoArgs(reader);
    if (line == NULL) {
        if (!PyErr_ExceptionMatches(PyExc_StopIteration)) return NULL;
        PyErr_Clear(); return PyBytes_FromStringAndSize("",0);
    }
    if (decode) {
        if (!PyBytes_Check(line)) {
            Py_DECREF(line); PyErr_SetString(PyExc_TypeError,"readline() returned a non-bytes object"); return NULL;
        }
        PyObject *text=PyUnicode_Decode(PyBytes_AS_STRING(line),PyBytes_GET_SIZE(line),encoding,"replace");
        Py_DECREF(line); line=text;
    } else if (!PyUnicode_Check(line)) {
        Py_DECREF(line); PyErr_SetString(PyExc_TypeError,"readline() returned a non-string"); return NULL;
    }
    return utf8_result(line);
}
PyObject *jacpy_source_bytes(PyObject *handle) {
    Py_buffer view;
    if (PyObject_GetBuffer(handle,&view,PyBUF_SIMPLE) < 0) return NULL;
    PyObject *copy=PyBytes_FromStringAndSize(view.buf,view.len);
    PyBuffer_Release(&view);
    return copy;
}
int64_t jacpy_source_kind(PyObject *handle) {
    PyObject *value=handle;
    if (PyUnicode_Check(value)) return 0;
    if (PyObject_CheckBuffer(value)) return 1;
    int is_ast=PyAST_Check(value);
    return is_ast > 0 ? 2 : -1;
}
int64_t jacpy_codec_valid(const char *name) {
    PyObject *codec=PyCodec_Encoder(name);
    if (codec == NULL) return 0;
    Py_DECREF(codec); return 1;
}
PyObject *jacpy_fd_line(int64_t fd) {
    PyObject *line=PyByteArray_FromStringAndSize(NULL,0);
    if (!line) return NULL;
    for (;;) {
        char ch; ssize_t count=read((int)fd,&ch,1);
        if (count < 0) { if (errno == EINTR) { if (PyErr_CheckSignals() < 0) { Py_DECREF(line); return NULL; } continue; } Py_DECREF(line); PyErr_SetFromErrno(PyExc_OSError); return NULL; }
        if (!count) break;
        Py_ssize_t length=PyByteArray_GET_SIZE(line);
        if (PyByteArray_Resize(line,length+1) < 0) { Py_DECREF(line); return NULL; }
        PyByteArray_AS_STRING(line)[length]=ch;
        if (ch == '\n') break;
    }
    PyObject *result=PyBytes_FromObject(line); Py_DECREF(line);
    return result;
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
#pragma GCC visibility pop
