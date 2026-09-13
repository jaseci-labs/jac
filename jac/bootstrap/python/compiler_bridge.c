/* ABI adapters for the Jac compiler. The excluded C compiler is not linked. */
#include "Python.h"
/* The evaluator still needs the retained, generated opcode tables. They were
   previously instantiated by codegen.c, which is no longer a build input. */
#define NEED_OPCODE_METADATA
#include "pycore_opcode_metadata.h"
#undef NEED_OPCODE_METADATA
#include "pycore_ast.h"
#include "pycore_compile.h"
#include "pycore_parser.h"
#include "pycore_symtable.h"
#include "pycore_pystate.h"
#include "pycore_interp.h"
#include "marshal.h"
#include "errcode.h"
#include "jac_compile.h"
#include <unistd.h>
#include <stdint.h>

/* These entry points are Jac-generated native code. No replacement bytecode
 * or Python callback is loaded by this adapter. String ABI arguments carry
 * owner, data, and explicit UTF-8 byte length. */
extern void *jac_str_new(const char *, int64_t);
extern void jac_release(void *);
extern void *jacpy_compile_object(uint64_t, uint64_t, void *, const char *, int64_t, int64_t, int64_t, int64_t);
extern int64_t jacpy_result_kind(void *);
extern int64_t jacpy_packet_size(void *);
extern int64_t jacpy_packet_byte(void *, int64_t);
extern uint64_t jacpy_ast_result(void *);
extern uint64_t jacpy_take_value(void *);
extern uint64_t jacpy_mangle(uint64_t, uint64_t);
extern int64_t jacpy_stack_effect(int64_t, int64_t, int64_t);

PyAPI_FUNC(int) _PyJac_CompilerBridgeVersion(void) { return 3; }
PyAPI_FUNC(int) _PyJac_SymtableBridgeVersion(void) { return 2; }
PyAPI_FUNC(int) _PyJac_TokenizeBridgeVersion(void) { return 2; }
PyAPI_FUNC(int) _PyJac_CompilerRequired(void) { return 1; }

static PyObject *jac_result(void *result)
{
    if (result == NULL) {
        if (!PyErr_Occurred()) PyErr_SetString(PyExc_SystemError,"native JacPython returned no result");
        return NULL;
    }
    int64_t kind=jacpy_result_kind(result);
    PyObject *value=NULL;
    if (kind == 1) value=(PyObject *)(uintptr_t)jacpy_ast_result(result);
    else if (kind == 2) value=(PyObject *)(uintptr_t)jacpy_take_value(result);
    else if (kind == 0) {
        int64_t size=jacpy_packet_size(result);
        if (size < 0) PyErr_SetString(PyExc_SystemError,"native JacPython could not encode its result");
        else {
            char *data=PyMem_Malloc((size_t)size);
            if (data == NULL) PyErr_NoMemory();
            else {
                for (int64_t i=0;i<size;i++) data[i]=(char)jacpy_packet_byte(result,i);
                value=PyMarshal_ReadObjectFromString(data,(Py_ssize_t)size);
                PyMem_Free(data);
            }
        }
    }
    jac_release(result);
    if (value == NULL) {
        if (!PyErr_Occurred()) PyErr_SetString(PyExc_SystemError,"native JacPython failed without an exception");
        return NULL;
    }
    if (PyTuple_Check(value) && PyTuple_GET_SIZE(value) == 8) {
        /* Native Jac has classified and positioned the diagnostic. Construct
         * the corresponding retained CPython exception value at the ABI. */
        PyObject *type=PyDict_GetItemWithError(PyEval_GetBuiltins(),PyTuple_GET_ITEM(value,0));
        if (type == NULL) { Py_DECREF(value); if (!PyErr_Occurred()) PyErr_SetString(PyExc_SystemError,"unknown native diagnostic"); return NULL; }
        if (PyObject_IsSubclass(type,PyExc_SyntaxError) > 0) {
            PyObject *location=PyTuple_GetSlice(value,2,8);
            PyObject *args=location ? PyTuple_Pack(2,PyTuple_GET_ITEM(value,1),location) : NULL;
            Py_XDECREF(location);
            if (args) { PyErr_SetObject(type,args); Py_DECREF(args); }
        } else PyErr_SetObject(type,PyTuple_GET_ITEM(value,1));
        Py_DECREF(value); return NULL;
    }
    return value;
}

PyObject *
_PyJac_CompileObject(PyObject *source, PyObject *filename, int start,
                     PyCompilerFlags *flags, int optimize)
{
    const char *mode;
    switch (start) {
        case Py_file_input: mode="exec"; break;
        case Py_eval_input: mode="eval"; break;
        case Py_single_input: mode="single"; break;
        case Py_func_type_input: mode="func_type"; break;
        default: PyErr_SetString(PyExc_ValueError,"invalid compilation mode"); return NULL;
    }
    if (PySys_Audit("compile","OO",source,filename) < 0) return NULL;
    int options=flags ? flags->cf_flags : 0;
    options &= ~(PyCF_SOURCE_IS_UTF8 | PyCF_IGNORE_COOKIE);
    int feature=flags ? flags->cf_feature_version : -1;
    if (optimize < 0) optimize=_PyInterpreterState_GetConfig(_PyInterpreterState_GET())->optimization_level;
    void *mode_string=jac_str_new(mode,(int64_t)strlen(mode));
    if (mode_string == NULL) return PyErr_NoMemory();
    void *native=jacpy_compile_object((uint64_t)(uintptr_t)source,(uint64_t)(uintptr_t)filename,
        mode_string,(const char *)mode_string,(int64_t)strlen(mode),optimize,options,feature);
    jac_release(mode_string);
    PyObject *result=jac_result(native);
    if (result == NULL) return NULL;
    if (!(options & PyCF_ONLY_AST) && !PyCode_Check(result)) {
        Py_DECREF(result); PyErr_SetString(PyExc_TypeError,"JacPython compiler must return a code object"); return NULL;
    }
    if (flags && PyCode_Check(result)) flags->cf_flags |= ((PyCodeObject *)result)->co_flags & PyCF_MASK;
    return result;
}

PyObject *
_PyJac_CompileString(const char *str, PyObject *filename, int start,
                     PyCompilerFlags *flags, int optimize)
{
    PyObject *source = flags && (flags->cf_flags & PyCF_IGNORE_COOKIE)
        ? PyUnicode_FromString(str) : PyBytes_FromString(str);
    if (source == NULL) return NULL;
    PyObject *result = _PyJac_CompileObject(source, filename, start, flags, optimize);
    Py_DECREF(source);
    return result;
}

static int
jac_append(PyObject *source, const char *data, Py_ssize_t size)
{
    Py_ssize_t previous = PyByteArray_GET_SIZE(source);
    if (size > PY_SSIZE_T_MAX - previous) { PyErr_NoMemory(); return -1; }
    if (PyByteArray_Resize(source, previous + size) < 0) return -1;
    memcpy(PyByteArray_AS_STRING(source) + previous, data, size);
    return 0;
}

static mod_ty
jac_parse_object(PyObject *source, PyObject *filename, int start,
                 PyCompilerFlags *flags, PyArena *arena)
{
    PyCompilerFlags cf = flags ? *flags : (PyCompilerFlags)_PyCompilerFlags_INIT;
    cf.cf_flags |= PyCF_ONLY_AST;
    PyObject *tree = _PyJac_CompileObject(source, filename, start, &cf, -1);
    if (tree == NULL) return NULL;
    int mode = start == Py_file_input ? 0 : start == Py_eval_input ? 1 : start == Py_single_input ? 2 : 3;
    mod_ty result = PyAST_obj2mod(tree, arena, mode);
    Py_DECREF(tree);
    return result;
}

mod_ty
_PyParser_ASTFromString(const char *str, PyObject *filename, int start,
                       PyCompilerFlags *flags, PyArena *arena)
{
    PyObject *source = flags && (flags->cf_flags & PyCF_IGNORE_COOKIE)
        ? PyUnicode_FromString(str) : PyBytes_FromString(str);
    if (source == NULL) return NULL;
    mod_ty result = jac_parse_object(source, filename, start, flags, arena);
    Py_DECREF(source);
    return result;
}

static PyObject *
jac_read_file(FILE *fp, const char *encoding)
{
    PyObject *data = PyByteArray_FromStringAndSize(NULL, 0);
    if (data == NULL) return NULL;
    char buffer[8192];
    size_t count;
    while ((count = fread(buffer, 1, sizeof(buffer), fp)) != 0) {
        if (jac_append(data, buffer, (Py_ssize_t)count) < 0) { Py_DECREF(data); return NULL; }
    }
    if (ferror(fp)) { Py_DECREF(data); PyErr_SetFromErrno(PyExc_OSError); return NULL; }
    PyObject *source = encoding
        ? PyUnicode_Decode(PyByteArray_AS_STRING(data), PyByteArray_GET_SIZE(data), encoding, "strict")
        : PyBytes_FromObject(data);
    Py_DECREF(data);
    return source;
}

PyObject *
_PyJac_CompileFile(FILE *fp, PyObject *filename, int start, PyCompilerFlags *flags)
{
    PyObject *source = jac_read_file(fp, NULL);
    if (source == NULL) return NULL;
    PyObject *result = _PyJac_CompileObject(source, filename, start, flags, -1);
    Py_DECREF(source);
    return result;
}

mod_ty
_PyParser_ASTFromFile(FILE *fp, PyObject *filename, const char *encoding,
                     int start, const char *ps1, const char *ps2,
                     PyCompilerFlags *flags, int *errcode, PyArena *arena)
{
    if (ps1 != NULL || ps2 != NULL) {
        PyObject *source = NULL;
        mod_ty result = _PyParser_InteractiveASTFromFile(fp, filename, encoding,
            start, ps1, ps2, flags, errcode, &source, arena);
        Py_XDECREF(source);
        return result;
    }
    PyObject *source = jac_read_file(fp, encoding);
    if (source == NULL) return NULL;
    mod_ty result = jac_parse_object(source, filename, start, flags, arena);
    Py_DECREF(source);
    if (errcode) *errcode = result ? E_DONE : E_ERROR;
    return result;
}

mod_ty
_PyParser_InteractiveASTFromFile(FILE *fp, PyObject *filename, const char *encoding,
                                int start, const char *ps1, const char *ps2,
                                PyCompilerFlags *flags, int *errcode,
                                PyObject **interactive_src, PyArena *arena)
{
    PyObject *data = PyByteArray_FromStringAndSize(NULL, 0);
    if (data == NULL) return NULL;
    *interactive_src = NULL;
    if (errcode) *errcode = E_ERROR;
    mod_ty result = NULL;
    for (;;) {
        int eof = 0;
        if (fp == stdin && (isatty(fileno(fp)) || _PyInterpreterState_GetConfig(_PyInterpreterState_GET())->interactive)) {
            const char *prompt = PyByteArray_GET_SIZE(data) == 0 ? ps1 : ps2;
            char *line = PyOS_Readline(fp, stdout, prompt ? prompt : "");
            if (line == NULL) { if (!PyErr_Occurred()) PyErr_SetNone(PyExc_KeyboardInterrupt); break; }
            Py_ssize_t size = (Py_ssize_t)strlen(line);
            int status = jac_append(data, line, size);
            PyMem_Free(line);
            if (status < 0) break;
            eof = size == 0;
        }
        else {
            int ch;
            while ((ch = fgetc(fp)) != EOF) {
                char byte = (char)ch;
                if (jac_append(data, &byte, 1) < 0) goto done;
                if (ch == '\n') break;
            }
            if (ferror(fp)) { PyErr_SetFromErrno(PyExc_OSError); break; }
            eof = ch == EOF;
        }
        if (eof && PyByteArray_GET_SIZE(data) == 0) {
            if (errcode) *errcode = E_EOF;
            break;
        }
        PyObject *source = encoding
            ? PyUnicode_Decode(PyByteArray_AS_STRING(data), PyByteArray_GET_SIZE(data), encoding, "strict")
            : PyBytes_FromObject(data);
        if (source == NULL) break;
        PyCompilerFlags cf = flags ? *flags : (PyCompilerFlags)_PyCompilerFlags_INIT;
        if (!eof) cf.cf_flags |= PyCF_ALLOW_INCOMPLETE_INPUT | PyCF_DONT_IMPLY_DEDENT;
        result = jac_parse_object(source, filename, start, &cf, arena);
        Py_DECREF(source);
        if (result != NULL) {
            *interactive_src = PyUnicode_Decode(PyByteArray_AS_STRING(data), PyByteArray_GET_SIZE(data),
                                                encoding ? encoding : "utf-8", "strict");
            if (*interactive_src == NULL) result = NULL;
            else if (errcode) *errcode = E_DONE;
            break;
        }
        if (!eof && PyErr_ExceptionMatches(PyExc_SyntaxError)) {
            PyObject *error = PyErr_GetRaisedException();
            PyObject *message = PyObject_GetAttrString(error, "msg");
            int incomplete = message && PyUnicode_Check(message) &&
                PyUnicode_CompareWithASCIIString(message, "incomplete input") == 0;
            Py_XDECREF(message);
            PyErr_Clear();
            if (incomplete) { Py_DECREF(error); continue; }
            PyErr_SetRaisedException(error);
        }
        break;
    }
done:
    Py_DECREF(data);
    return result;
}

PyCodeObject *
_PyAST_Compile(mod_ty tree, PyObject *filename, PyCompilerFlags *flags,
               int optimize, PyArena *arena)
{
    PyObject *source = PyAST_mod2obj(tree);
    if (source == NULL) return NULL;
    int start = tree->kind == Module_kind ? Py_file_input : tree->kind == Interactive_kind ? Py_single_input : Py_eval_input;
    PyObject *result = _PyJac_CompileObject(source, filename, start, flags, optimize);
    Py_DECREF(source);
    return (PyCodeObject *)result;
}

PyObject *
_Py_Mangle(PyObject *privateobj, PyObject *name)
{
    /* A missing/non-string private value means there is no class context. */
    if (privateobj == NULL || !PyUnicode_Check(privateobj)) return Py_NewRef(name);
    return (PyObject *)(uintptr_t)jacpy_mangle((uint64_t)(uintptr_t)privateobj,(uint64_t)(uintptr_t)name);
}

int
PyCompile_OpcodeStackEffectWithJump(int opcode, int oparg, int jump)
{
    return (int)jacpy_stack_effect(opcode,oparg,jump);
}

int PyCompile_OpcodeStackEffect(int opcode, int oparg)
{
    return PyCompile_OpcodeStackEffectWithJump(opcode, oparg, -1);
}

char *
_PyTokenizer_FindEncodingFilename(int fd, PyObject *filename)
{
    extern uint64_t jacpy_fd_encoding(int64_t);
    PyObject *result=(PyObject *)(uintptr_t)jacpy_fd_encoding(fd);
    if (result == NULL) return NULL;
    PyObject *encoding=result;
    Py_ssize_t length;
    const char *text = encoding ? PyUnicode_AsUTF8AndSize(encoding, &length) : NULL;
    char *copy = NULL;
    if (text != NULL) {
        copy = PyMem_Malloc((size_t)length + 1);
        if (copy != NULL) memcpy(copy, text, (size_t)length + 1);
        else PyErr_NoMemory();
    }
    Py_DECREF(result);
    return copy;
}

static PyObject *jac_symtable(PyObject *self, PyObject *args)
{
    extern void *jacpy_symtable_object(uint64_t,uint64_t,void *,const char *,int64_t);
    PyObject *source,*filename;
    const char *mode;
    if (!PyArg_ParseTuple(args,"OO&s:symtable",&source,PyUnicode_FSDecoder,&filename,&mode)) return NULL;
    int64_t length=(int64_t)strlen(mode);
    void *text=jac_str_new(mode,length);
    if (!text) { Py_DECREF(filename); return PyErr_NoMemory(); }
    void *native=jacpy_symtable_object((uint64_t)(uintptr_t)source,(uint64_t)(uintptr_t)filename,text,(const char *)text,length);
    jac_release(text); Py_DECREF(filename);
    return jac_result(native);
}
/* Retained Python iterator value around the native Jac stream state. */
extern void *jacpy_token_create(uint64_t, void *, const char *, int64_t, _Bool, _Bool);
extern void *jacpy_token_step(void *);
extern void jacpy_token_dispose(void *);
typedef struct { PyObject_HEAD PyObject *reader; void *iterator; } JacTokenizer;
static int jac_token_traverse(PyObject *object, visitproc visit, void *arg) {
    Py_VISIT(((JacTokenizer *)object)->reader); return 0;
}
static int jac_token_clear(PyObject *object) {
    JacTokenizer *self=(JacTokenizer *)object;
    if (self->iterator) { jacpy_token_dispose(self->iterator); jac_release(self->iterator); self->iterator=NULL; }
    Py_CLEAR(self->reader); return 0;
}
static void jac_token_dealloc(PyObject *object) {
    PyTypeObject *type=Py_TYPE(object); PyObject_GC_UnTrack(object);
    jac_token_clear(object); type->tp_free(object); Py_DECREF(type);
}
static PyObject *jac_token_next(PyObject *object) {
    JacTokenizer *self=(JacTokenizer *)object;
    if (self->iterator == NULL) return NULL;
    void *result=jacpy_token_step(self->iterator);
    if (result && jacpy_result_kind(result) == 3) { jac_release(result); return NULL; }
    return jac_result(result);
}
static PyType_Slot jac_token_slots[] = {
    {Py_tp_dealloc,jac_token_dealloc},{Py_tp_traverse,jac_token_traverse},
    {Py_tp_clear,jac_token_clear},{Py_tp_iter,PyObject_SelfIter},
    {Py_tp_iternext,jac_token_next},{0,NULL}
};
static PyType_Spec jac_token_spec = {
    .name="_tokenize.TokenizerIter",.basicsize=sizeof(JacTokenizer),
    .flags=Py_TPFLAGS_DEFAULT|Py_TPFLAGS_HAVE_GC,.slots=jac_token_slots
};
static PyObject *jac_tokenize(PyObject *module, PyObject *args, PyObject *kwargs) {
    PyObject *reader,*extra=NULL,*encoding=NULL;
    static char *keywords[]={"readline","extra_tokens","encoding",NULL};
    if (!PyArg_ParseTupleAndKeywords(args,kwargs,"O|$OO:TokenizerIter",keywords,&reader,&extra,&encoding)) return NULL;
    if (!extra) { PyErr_SetString(PyExc_TypeError,"tokenizeriter() missing required argument 'extra_tokens' (pos 2)"); return NULL; }
    if (encoding && !PyUnicode_Check(encoding)) { PyErr_SetString(PyExc_TypeError,"tokenizeriter() argument 'encoding' must be str"); return NULL; }
    Py_ssize_t size=0;
    const char *text=encoding ? PyUnicode_AsUTF8AndSize(encoding,&size) : "";
    if (!text) return NULL;
    if (memchr(text,0,(size_t)size)) { PyErr_SetString(PyExc_ValueError,"embedded null character"); return NULL; }
    int extra_flag=PyObject_IsTrue(extra);
    if (extra_flag < 0) return NULL;
    PyObject *type=PyObject_GetAttrString(module,"_Iterator");
    if (!type) return NULL;
    JacTokenizer *result=(JacTokenizer *)PyType_GenericAlloc((PyTypeObject *)type,0);
    Py_DECREF(type);
    if (!result) return NULL;
    result->reader=Py_NewRef(reader);
    void *enc=jac_str_new(text,size);
    if (!enc) { Py_DECREF(result); return PyErr_NoMemory(); }
    result->iterator=jacpy_token_create((uint64_t)(uintptr_t)reader,enc,(const char *)enc,size,encoding!=NULL,extra_flag!=0);
    jac_release(enc);
    if (!result->iterator) { Py_DECREF(result); if (!PyErr_Occurred()) PyErr_NoMemory(); return NULL; }
    return (PyObject *)result;
}
static int jac_token_exec(PyObject *module) {
    PyObject *type=PyType_FromModuleAndSpec(module,&jac_token_spec,NULL);
    if (!type) return -1;
    int status=PyModule_AddObjectRef(module,"_Iterator",type);
    Py_DECREF(type); return status;
}

static int jac_symtable_constants(PyObject *module)
{
#define ADD(name) if (PyModule_AddIntConstant(module, #name, name) < 0) return -1
    ADD(USE); ADD(DEF_GLOBAL); ADD(DEF_NONLOCAL); ADD(DEF_LOCAL); ADD(DEF_PARAM);
    ADD(DEF_TYPE_PARAM); ADD(DEF_FREE_CLASS); ADD(DEF_IMPORT); ADD(DEF_BOUND);
    ADD(DEF_ANNOT); ADD(DEF_COMP_ITER); ADD(DEF_COMP_CELL);
    ADD(LOCAL); ADD(GLOBAL_EXPLICIT); ADD(GLOBAL_IMPLICIT); ADD(FREE); ADD(CELL); ADD(SCOPE_MASK);
#undef ADD
#define ADD(name, value) if (PyModule_AddIntConstant(module, name, value) < 0) return -1
    ADD("SCOPE_OFF", SCOPE_OFFSET); ADD("TYPE_FUNCTION", FunctionBlock);
    ADD("TYPE_CLASS", ClassBlock); ADD("TYPE_MODULE", ModuleBlock);
    ADD("TYPE_ANNOTATION", AnnotationBlock); ADD("TYPE_TYPE_ALIAS", TypeAliasBlock);
    ADD("TYPE_TYPE_PARAMETERS", TypeParametersBlock); ADD("TYPE_TYPE_VARIABLE", TypeVariableBlock);
#undef ADD
    return 0;
}
static PyMethodDef symtable_methods[] = {
    {"symtable", jac_symtable, METH_VARARGS, "Build a symbol table with JacPython."},
    {NULL, NULL, 0, NULL}
};
static PyMethodDef tokenize_methods[] = {
    {"TokenizerIter", (PyCFunction)(void(*)(void))jac_tokenize, METH_VARARGS | METH_KEYWORDS,
     "Construct JacPython's streaming token iterator."},
    {NULL, NULL, 0, NULL}
};
static PyModuleDef_Slot symtable_slots[] = {
    {Py_mod_exec, jac_symtable_constants},
    {Py_mod_multiple_interpreters, Py_MOD_PER_INTERPRETER_GIL_SUPPORTED},
    {0, NULL}
};
static PyModuleDef_Slot tokenize_slots[] = {
    {Py_mod_exec, jac_token_exec},
    {Py_mod_multiple_interpreters, Py_MOD_PER_INTERPRETER_GIL_SUPPORTED},
    {0, NULL}
};
static struct PyModuleDef symtable_module = {
    PyModuleDef_HEAD_INIT, .m_name = "_symtable", .m_size = 0,
    .m_methods = symtable_methods, .m_slots = symtable_slots
};
static struct PyModuleDef tokenize_module = {
    PyModuleDef_HEAD_INIT, .m_name = "_tokenize", .m_size = 0,
    .m_methods = tokenize_methods, .m_slots = tokenize_slots
};
PyMODINIT_FUNC PyInit__symtable(void) { return PyModuleDef_Init(&symtable_module); }
PyMODINIT_FUNC PyInit__tokenize(void) { return PyModuleDef_Init(&tokenize_module); }
