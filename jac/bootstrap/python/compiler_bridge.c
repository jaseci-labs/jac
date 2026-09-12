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
#include "jac_seed.h"
#include <unistd.h>
#include <zlib.h>

PyAPI_FUNC(int) _PyJac_CompilerBridgeVersion(void) { return 2; }
PyAPI_FUNC(int) _PyJac_SymtableBridgeVersion(void) { return 1; }
PyAPI_FUNC(int) _PyJac_TokenizeBridgeVersion(void) { return 1; }
PyAPI_FUNC(int) _PyJac_CompilerRequired(void) { return 1; }

static PyObject *
jac_image(void)
{
    PyObject *image = PySys_GetObject("_jacpython_image");
    if (image != NULL) return image;
    unsigned char *data = PyMem_Malloc(JAC_SEED_SIZE);
    if (data == NULL) { PyErr_NoMemory(); return NULL; }
    uLongf size = JAC_SEED_SIZE;
    int status = uncompress(data, &size, jac_seed_data, sizeof(jac_seed_data));
    if (status != Z_OK || size != JAC_SEED_SIZE) {
        PyMem_Free(data);
        PyErr_SetString(PyExc_RuntimeError, "Corrupt JacPython seed image");
        return NULL;
    }
    image = PyMarshal_ReadObjectFromString((const char *)data, (Py_ssize_t)size);
    PyMem_Free(data);
    if (image == NULL) return NULL;
    if (!PyDict_Check(image)) {
        Py_DECREF(image);
        PyErr_SetString(PyExc_RuntimeError, "Invalid JacPython seed image");
        return NULL;
    }
    status = PySys_SetObject("_jacpython_image", image);
    Py_DECREF(image);
    return status < 0 ? NULL : PySys_GetObject("_jacpython_image");
}

static int
jac_initialize(void)
{
    PyObject *image = jac_image();
    if (image == NULL) return -1;
    if (PyDict_GetItemString(image, "ready") != NULL) return 0;
    if (PyDict_GetItemString(image, "loading") != NULL) {
        PyErr_SetString(PyExc_RuntimeError, "Unprepared compilation during JacPython bootstrap");
        return -1;
    }
    PyObject *code = PyDict_GetItemString(image, "loader");
    if (code == NULL || !PyCode_Check(code)) {
        PyErr_SetString(PyExc_RuntimeError, "Missing JacPython seed loader");
        return -1;
    }
    if (PyDict_SetItemString(image, "loading", Py_True) < 0) return -1;
    PyObject *module = PyImport_AddModuleRef("_jacpython_seed");
    PyObject *scope = module ? PyModule_GetDict(module) : NULL;
    PyObject *result = NULL;
    if (scope != NULL && PyDict_SetItemString(scope, "image", image) == 0 &&
        PyDict_SetItemString(scope, "__builtins__", PyEval_GetBuiltins()) == 0) {
        result = PyEval_EvalCode(code, scope, scope);
    }
    Py_XDECREF(module);
    if (result == NULL) {
        /* Preserve the original failure, and never retry a partial bootstrap. */
        return -1;
    }
    Py_DECREF(result);
    if (PyDict_DelItemString(image, "loading") < 0 ||
        PyDict_SetItemString(image, "ready", Py_True) < 0) return -1;
    /* Prepared code is only for startup; retire it once Jac can compile. */
    return PyDict_DelItemString(image, "requests");
}

static PyObject *
jac_callback(const char *name)
{
    PyObject *callback = PySys_GetObject(name);
    if (callback == NULL || callback == Py_None) {
        if (jac_initialize() < 0) return NULL;
        callback = PySys_GetObject(name);
    }
    if (callback == NULL || callback == Py_None) {
        PyErr_Format(PyExc_RuntimeError, "Missing JacPython callback: %s", name);
        return NULL;
    }
    return Py_NewRef(callback);
}

static PyObject *
jac_prepared_code(PyObject *source, const char *mode, int flags, int optimize, int feature)
{
    if (!PyUnicode_Check(source) && !PyBytes_Check(source)) return NULL;
    PyObject *image = jac_image();
    if (image == NULL) return NULL;
    if (PyDict_GetItemString(image, "ready") != NULL) return NULL;
    PyObject *requests = PyDict_GetItemString(image, "requests");
    if (requests == NULL || !PyDict_Check(requests)) {
        PyErr_SetString(PyExc_RuntimeError, "Missing JacPython bootstrap requests");
        return NULL;
    }
    if (optimize < 0) optimize = _PyInterpreterState_GetConfig(_PyInterpreterState_GET())->optimization_level;
    PyObject *key = Py_BuildValue("(Osiii)", source, mode, flags, optimize, feature);
    if (key == NULL) return NULL;
    PyObject *code = PyDict_GetItemWithError(requests, key);
    Py_XINCREF(code);
    Py_DECREF(key);
    return code;
}

PyObject *
_PyJac_CompileObject(PyObject *source, PyObject *filename, int start,
                     PyCompilerFlags *flags, int optimize)
{
    const char *mode;
    switch (start) {
        case Py_file_input: mode = "exec"; break;
        case Py_eval_input: mode = "eval"; break;
        case Py_single_input: mode = "single"; break;
        case Py_func_type_input: mode = "func_type"; break;
        default:
            PyErr_SetString(PyExc_ValueError, "invalid compilation mode");
            return NULL;
    }
    if (PySys_Audit("compile", "OO", source, filename) < 0) return NULL;
    int options = flags ? flags->cf_flags : 0;
    options &= ~(PyCF_SOURCE_IS_UTF8 | PyCF_IGNORE_COOKIE);
    int feature = flags ? flags->cf_feature_version : -1;
    PyObject *result = NULL;
    PyObject *compiler = PySys_GetObject("_jacpython_compile");
    if (compiler == NULL || compiler == Py_None) {
        result = jac_prepared_code(source, mode, options, optimize, feature);
        if (result == NULL && PyErr_Occurred()) return NULL;
        if (result != NULL) {
            /* Startup bytecode carries virtual build-independent filenames.
               Restore the importing runtime's path, including nested code,
               just as importlib does when loading a relocated bytecode file. */
            PyObject *fix = PyImport_ImportModuleAttrString("_imp", "_fix_co_filename");
            PyObject *fixed = fix ? PyObject_CallFunctionObjArgs(fix, result, filename, NULL) : NULL;
            Py_XDECREF(fix);
            if (fixed == NULL) { Py_DECREF(result); return NULL; }
            Py_DECREF(fixed);
        }
    }
    if (result == NULL) {
        compiler = jac_callback("_jacpython_compile");
        if (compiler == NULL) return NULL;
        PyObject *args = Py_BuildValue("(OOsiii)", source, filename, mode, options, 1, optimize);
        PyObject *kwargs = args ? Py_BuildValue("{s:i}", "_feature_version", feature) : NULL;
        if (kwargs != NULL) result = PyObject_Call(compiler, args, kwargs);
        Py_XDECREF(args);
        Py_XDECREF(kwargs);
        Py_DECREF(compiler);
    }
    if (result == NULL) return NULL;
    if (!(options & PyCF_ONLY_AST) && !PyCode_Check(result)) {
        Py_DECREF(result);
        PyErr_SetString(PyExc_TypeError, "JacPython compiler must return a code object");
        return NULL;
    }
    if (flags && PyCode_Check(result)) {
        flags->cf_flags |= ((PyCodeObject *)result)->co_flags & PyCF_MASK;
    }
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
    Py_ssize_t size = PyUnicode_GET_LENGTH(name);
    if (privateobj == NULL || !PyUnicode_Check(privateobj) || size < 2 ||
        PyUnicode_READ_CHAR(name, 0) != '_' || PyUnicode_READ_CHAR(name, 1) != '_' ||
        (PyUnicode_READ_CHAR(name, size-1) == '_' && PyUnicode_READ_CHAR(name, size-2) == '_')) {
        return Py_NewRef(name);
    }
    PyObject *callback = jac_callback("_jacpython_mangle");
    if (callback == NULL) return NULL;
    PyObject *result = PyObject_CallFunctionObjArgs(callback, privateobj, name, NULL);
    Py_DECREF(callback);
    return result;
}

int
PyCompile_OpcodeStackEffectWithJump(int opcode, int oparg, int jump)
{
    PyObject *callback = jac_callback("_jacpython_stack_effect");
    if (callback == NULL) return PY_INVALID_STACK_EFFECT;
    PyObject *result = PyObject_CallFunction(callback, "iii", opcode, oparg, jump);
    Py_DECREF(callback);
    if (result == NULL) return PY_INVALID_STACK_EFFECT;
    int effect = result == Py_None ? PY_INVALID_STACK_EFFECT : PyLong_AsInt(result);
    Py_DECREF(result);
    return effect;
}

int PyCompile_OpcodeStackEffect(int opcode, int oparg)
{
    return PyCompile_OpcodeStackEffectWithJump(opcode, oparg, -1);
}

char *
_PyTokenizer_FindEncodingFilename(int fd, PyObject *filename)
{
    PyObject *io = PyImport_ImportModule("io");
    PyObject *open = io ? PyObject_GetAttrString(io, "FileIO") : NULL;
    Py_XDECREF(io);
    if (open == NULL) return NULL;
    PyObject *args = Py_BuildValue("(is)", fd, "r");
    PyObject *kwargs = args ? Py_BuildValue("{s:O}", "closefd", Py_False) : NULL;
    PyObject *stream = kwargs ? PyObject_Call(open, args, kwargs) : NULL;
    Py_XDECREF(args); Py_XDECREF(kwargs); Py_DECREF(open);
    if (stream == NULL) return NULL;
    PyObject *reader = PyObject_GetAttrString(stream, "readline");
    PyObject *detect = reader ? PyImport_ImportModuleAttrString("tokenize", "detect_encoding") : NULL;
    PyObject *result = detect ? PyObject_CallOneArg(detect, reader) : NULL;
    Py_XDECREF(detect); Py_XDECREF(reader); Py_DECREF(stream);
    if (result == NULL) return NULL;
    PyObject *encoding = PyTuple_GetItem(result, 0);
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
    PyObject *callback = jac_callback("_jacpython_symtable");
    if (callback == NULL) return NULL;
    PyObject *result = PyObject_CallObject(callback, args);
    Py_DECREF(callback);
    return result;
}
static PyObject *jac_tokenize(PyObject *self, PyObject *args, PyObject *kwargs)
{
    PyObject *callback = jac_callback("_jacpython_tokenize");
    if (callback == NULL) return NULL;
    PyObject *result = PyObject_Call(callback, args, kwargs);
    Py_DECREF(callback);
    return result;
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
