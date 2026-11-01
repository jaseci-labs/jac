"""The C API declarations of the generated headers.

One entry per declaration, in header order: the header, the `#if` condition
it sits under (the conjunction of its enclosing branches, include guards
aside; empty when it is unconditional) and its C text, comments dropped and
white space collapsed. The entries are every `PyAPI_FUNC` and `PyAPI_DATA`
declaration of Include/ and the plain `extern` functions and variables of
Include/internal/, which jacpython.o resolves against libpython itself.

gen_include.jac writes the headers' declarations from this table (a new entry
is added at the end of its header under its condition, an entry removed
drops its declaration) and gen_capi.jac types python_capi.jac's externs from
it.

CONDITIONAL_STRUCTS holds the struct of each layouts.jac record whose header
definition the release build's view does not cover: one with preprocessor
branches, or defined more than once under different conditions (`struct
_object` with and without the free-threaded refcount). Each entry is the
header, the condition of the definition, the C type and the lines of its body
between the braces. gen_include.jac writes the body from it, and its release
build branches must declare the record's members.
"""

glob DECLARATIONS: list[tuple[str, str, str]] = [
         (
             "Include/abstract.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03090000)",
             "PyAPI_FUNC(PyObject *) PyObject_CallNoArgs(PyObject *func);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyObject_Call(PyObject *callable, PyObject *args, PyObject *kwargs);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyObject_CallObject(PyObject *callable, PyObject *args);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyObject_CallFunction(PyObject *callable, const char *format, ...);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyObject_CallMethod(PyObject *obj, const char *name, const char *format, ...);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyObject_CallFunctionObjArgs(PyObject *callable, ...);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyObject_CallMethodObjArgs( PyObject *obj, PyObject *name, ...);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) PyVectorcall_NARGS(size_t nargsf);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyVectorcall_Call(PyObject *callable, PyObject *tuple, PyObject *dict);"
         ),
         (
             "Include/abstract.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030C0000)",
             "PyAPI_FUNC(PyObject *) PyObject_Vectorcall( PyObject *callable, PyObject *const *args, size_t nargsf, PyObject *kwnames);"
         ),
         (
             "Include/abstract.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030C0000)",
             "PyAPI_FUNC(PyObject *) PyObject_VectorcallMethod( PyObject *name, PyObject *const *args, size_t nargsf, PyObject *kwnames);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyObject_Type(PyObject *o);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) PyObject_Size(PyObject *o);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) PyObject_Length(PyObject *o);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyObject_GetItem(PyObject *o, PyObject *key);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(int) PyObject_SetItem(PyObject *o, PyObject *key, PyObject *v);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(int) PyObject_DelItemString(PyObject *o, const char *key);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(int) PyObject_DelItem(PyObject *o, PyObject *key);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyObject_Format(PyObject *obj, PyObject *format_spec);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyObject_GetIter(PyObject *);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyObject_GetAIter(PyObject *);"
         ),
         ("Include/abstract.h", "", "PyAPI_FUNC(int) PyIter_Check(PyObject *);"),
         ("Include/abstract.h", "", "PyAPI_FUNC(int) PyAIter_Check(PyObject *);"),
         (
             "Include/abstract.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030e0000)",
             "PyAPI_FUNC(int) PyIter_NextItem(PyObject *iter, PyObject **item);"
         ),
         ("Include/abstract.h", "", "PyAPI_FUNC(PyObject *) PyIter_Next(PyObject *);"),
         (
             "Include/abstract.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030A0000)",
             "PyAPI_FUNC(PySendResult) PyIter_Send(PyObject *, PyObject *, PyObject **);"
         ),
         ("Include/abstract.h", "", "PyAPI_FUNC(int) PyNumber_Check(PyObject *o);"),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_Add(PyObject *o1, PyObject *o2);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_Subtract(PyObject *o1, PyObject *o2);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_Multiply(PyObject *o1, PyObject *o2);"
         ),
         (
             "Include/abstract.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03050000)",
             "PyAPI_FUNC(PyObject *) PyNumber_MatrixMultiply(PyObject *o1, PyObject *o2);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_FloorDivide(PyObject *o1, PyObject *o2);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_TrueDivide(PyObject *o1, PyObject *o2);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_Remainder(PyObject *o1, PyObject *o2);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_Divmod(PyObject *o1, PyObject *o2);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_Power(PyObject *o1, PyObject *o2, PyObject *o3);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_Negative(PyObject *o);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_Positive(PyObject *o);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_Absolute(PyObject *o);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_Invert(PyObject *o);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_Lshift(PyObject *o1, PyObject *o2);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_Rshift(PyObject *o1, PyObject *o2);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_And(PyObject *o1, PyObject *o2);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_Xor(PyObject *o1, PyObject *o2);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_Or(PyObject *o1, PyObject *o2);"
         ),
         ("Include/abstract.h", "", "PyAPI_FUNC(int) PyIndex_Check(PyObject *);"),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_Index(PyObject *o);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) PyNumber_AsSsize_t(PyObject *o, PyObject *exc);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_Long(PyObject *o);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_Float(PyObject *o);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_InPlaceAdd(PyObject *o1, PyObject *o2);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_InPlaceSubtract(PyObject *o1, PyObject *o2);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_InPlaceMultiply(PyObject *o1, PyObject *o2);"
         ),
         (
             "Include/abstract.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03050000)",
             "PyAPI_FUNC(PyObject *) PyNumber_InPlaceMatrixMultiply(PyObject *o1, PyObject *o2);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_InPlaceFloorDivide(PyObject *o1, PyObject *o2);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_InPlaceTrueDivide(PyObject *o1, PyObject *o2);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_InPlaceRemainder(PyObject *o1, PyObject *o2);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_InPlacePower(PyObject *o1, PyObject *o2, PyObject *o3);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_InPlaceLshift(PyObject *o1, PyObject *o2);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_InPlaceRshift(PyObject *o1, PyObject *o2);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_InPlaceAnd(PyObject *o1, PyObject *o2);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_InPlaceXor(PyObject *o1, PyObject *o2);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_InPlaceOr(PyObject *o1, PyObject *o2);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyNumber_ToBase(PyObject *n, int base);"
         ),
         ("Include/abstract.h", "", "PyAPI_FUNC(int) PySequence_Check(PyObject *o);"),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) PySequence_Size(PyObject *o);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) PySequence_Length(PyObject *o);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PySequence_Concat(PyObject *o1, PyObject *o2);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PySequence_Repeat(PyObject *o, Py_ssize_t count);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PySequence_GetItem(PyObject *o, Py_ssize_t i);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PySequence_GetSlice(PyObject *o, Py_ssize_t i1, Py_ssize_t i2);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(int) PySequence_SetItem(PyObject *o, Py_ssize_t i, PyObject *v);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(int) PySequence_DelItem(PyObject *o, Py_ssize_t i);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(int) PySequence_SetSlice(PyObject *o, Py_ssize_t i1, Py_ssize_t i2, PyObject *v);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(int) PySequence_DelSlice(PyObject *o, Py_ssize_t i1, Py_ssize_t i2);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PySequence_Tuple(PyObject *o);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PySequence_List(PyObject *o);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PySequence_Fast(PyObject *o, const char* m);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) PySequence_Count(PyObject *o, PyObject *value);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(int) PySequence_Contains(PyObject *seq, PyObject *ob);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(int) PySequence_In(PyObject *o, PyObject *value);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) PySequence_Index(PyObject *o, PyObject *value);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PySequence_InPlaceConcat(PyObject *o1, PyObject *o2);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PySequence_InPlaceRepeat(PyObject *o, Py_ssize_t count);"
         ),
         ("Include/abstract.h", "", "PyAPI_FUNC(int) PyMapping_Check(PyObject *o);"),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) PyMapping_Size(PyObject *o);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) PyMapping_Length(PyObject *o);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(int) PyMapping_HasKeyString(PyObject *o, const char *key);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(int) PyMapping_HasKey(PyObject *o, PyObject *key);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(int) PyMapping_HasKeyWithError(PyObject *o, PyObject *key);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(int) PyMapping_HasKeyStringWithError(PyObject *o, const char *key);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyMapping_Keys(PyObject *o);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyMapping_Values(PyObject *o);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyMapping_Items(PyObject *o);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyMapping_GetItemString(PyObject *o, const char *key);"
         ),
         (
             "Include/abstract.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030d0000)",
             "PyAPI_FUNC(int) PyMapping_GetOptionalItem(PyObject *, PyObject *, PyObject **);"
         ),
         (
             "Include/abstract.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030d0000)",
             "PyAPI_FUNC(int) PyMapping_GetOptionalItemString(PyObject *, const char *, PyObject **);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(int) PyMapping_SetItemString(PyObject *o, const char *key, PyObject *value);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(int) PyObject_IsInstance(PyObject *object, PyObject *typeorclass);"
         ),
         (
             "Include/abstract.h",
             "",
             "PyAPI_FUNC(int) PyObject_IsSubclass(PyObject *object, PyObject *typeorclass);"
         ),
         (
             "Include/audit.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030d0000)",
             "PyAPI_FUNC(int) PySys_Audit( const char *event, const char *argFormat, ...);"
         ),
         (
             "Include/audit.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030d0000)",
             "PyAPI_FUNC(int) PySys_AuditTuple( const char *event, PyObject *args);"
         ),
         ("Include/bltinmodule.h", "", "PyAPI_DATA(PyTypeObject) PyFilter_Type;"),
         ("Include/bltinmodule.h", "", "PyAPI_DATA(PyTypeObject) PyMap_Type;"),
         ("Include/bltinmodule.h", "", "PyAPI_DATA(PyTypeObject) PyZip_Type;"),
         ("Include/boolobject.h", "", "PyAPI_DATA(PyLongObject) _Py_FalseStruct;"),
         ("Include/boolobject.h", "", "PyAPI_DATA(PyLongObject) _Py_TrueStruct;"),
         ("Include/boolobject.h", "", "PyAPI_FUNC(int) Py_IsTrue(PyObject *x);"),
         ("Include/boolobject.h", "", "PyAPI_FUNC(int) Py_IsFalse(PyObject *x);"),
         ("Include/boolobject.h", "", "PyAPI_FUNC(PyObject *) PyBool_FromLong(long);"),
         (
             "Include/bytearrayobject.h",
             "",
             "PyAPI_DATA(PyTypeObject) PyByteArray_Type;"
         ),
         (
             "Include/bytearrayobject.h",
             "",
             "PyAPI_DATA(PyTypeObject) PyByteArrayIter_Type;"
         ),
         (
             "Include/bytearrayobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyByteArray_FromObject(PyObject *);"
         ),
         (
             "Include/bytearrayobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyByteArray_Concat(PyObject *, PyObject *);"
         ),
         (
             "Include/bytearrayobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyByteArray_FromStringAndSize(const char *, Py_ssize_t);"
         ),
         (
             "Include/bytearrayobject.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) PyByteArray_Size(PyObject *);"
         ),
         (
             "Include/bytearrayobject.h",
             "",
             "PyAPI_FUNC(char *) PyByteArray_AsString(PyObject *);"
         ),
         (
             "Include/bytearrayobject.h",
             "",
             "PyAPI_FUNC(int) PyByteArray_Resize(PyObject *, Py_ssize_t);"
         ),
         ("Include/bytesobject.h", "", "PyAPI_DATA(PyTypeObject) PyBytes_Type;"),
         ("Include/bytesobject.h", "", "PyAPI_DATA(PyTypeObject) PyBytesIter_Type;"),
         (
             "Include/bytesobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyBytes_FromStringAndSize(const char *, Py_ssize_t);"
         ),
         (
             "Include/bytesobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyBytes_FromString(const char *);"
         ),
         (
             "Include/bytesobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyBytes_FromObject(PyObject *);"
         ),
         (
             "Include/bytesobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyBytes_FromFormatV(const char*, va_list) Py_GCC_ATTRIBUTE((format(printf, 1, 0)));"
         ),
         (
             "Include/bytesobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyBytes_FromFormat(const char*, ...) Py_GCC_ATTRIBUTE((format(printf, 1, 2)));"
         ),
         (
             "Include/bytesobject.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) PyBytes_Size(PyObject *);"
         ),
         (
             "Include/bytesobject.h",
             "",
             "PyAPI_FUNC(char *) PyBytes_AsString(PyObject *);"
         ),
         (
             "Include/bytesobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyBytes_Repr(PyObject *, int);"
         ),
         (
             "Include/bytesobject.h",
             "",
             "PyAPI_FUNC(void) PyBytes_Concat(PyObject **, PyObject *);"
         ),
         (
             "Include/bytesobject.h",
             "",
             "PyAPI_FUNC(void) PyBytes_ConcatAndDel(PyObject **, PyObject *);"
         ),
         (
             "Include/bytesobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyBytes_DecodeEscape(const char *, Py_ssize_t, const char *, Py_ssize_t, const char *);"
         ),
         (
             "Include/bytesobject.h",
             "",
             "PyAPI_FUNC(int) PyBytes_AsStringAndSize( PyObject *obj, char **s, Py_ssize_t *len );"
         ),
         (
             "Include/ceval.h",
             "",
             "PyAPI_FUNC(PyObject *) PyEval_EvalCode(PyObject *, PyObject *, PyObject *);"
         ),
         (
             "Include/ceval.h",
             "",
             "PyAPI_FUNC(PyObject *) PyEval_EvalCodeEx(PyObject *co, PyObject *globals, PyObject *locals, PyObject *const *args, int argc, PyObject *const *kwds, int kwdc, PyObject *const *defs, int defc, PyObject *kwdefs, PyObject *closure);"
         ),
         ("Include/ceval.h", "", "PyAPI_FUNC(PyObject *) PyEval_GetBuiltins(void);"),
         ("Include/ceval.h", "", "PyAPI_FUNC(PyObject *) PyEval_GetGlobals(void);"),
         ("Include/ceval.h", "", "PyAPI_FUNC(PyObject *) PyEval_GetLocals(void);"),
         ("Include/ceval.h", "", "PyAPI_FUNC(PyFrameObject *) PyEval_GetFrame(void);"),
         (
             "Include/ceval.h",
             "",
             "PyAPI_FUNC(PyObject *) PyEval_GetFrameBuiltins(void);"
         ),
         (
             "Include/ceval.h",
             "",
             "PyAPI_FUNC(PyObject *) PyEval_GetFrameGlobals(void);"
         ),
         ("Include/ceval.h", "", "PyAPI_FUNC(PyObject *) PyEval_GetFrameLocals(void);"),
         (
             "Include/ceval.h",
             "",
             "PyAPI_FUNC(int) Py_AddPendingCall(int (*func)(void *), void *arg);"
         ),
         ("Include/ceval.h", "", "PyAPI_FUNC(int) Py_MakePendingCalls(void);"),
         ("Include/ceval.h", "", "PyAPI_FUNC(void) Py_SetRecursionLimit(int);"),
         ("Include/ceval.h", "", "PyAPI_FUNC(int) Py_GetRecursionLimit(void);"),
         (
             "Include/ceval.h",
             "",
             "PyAPI_FUNC(int) Py_EnterRecursiveCall(const char *where);"
         ),
         ("Include/ceval.h", "", "PyAPI_FUNC(void) Py_LeaveRecursiveCall(void);"),
         (
             "Include/ceval.h",
             "",
             "PyAPI_FUNC(const char *) PyEval_GetFuncName(PyObject *);"
         ),
         (
             "Include/ceval.h",
             "",
             "PyAPI_FUNC(const char *) PyEval_GetFuncDesc(PyObject *);"
         ),
         (
             "Include/ceval.h",
             "",
             "PyAPI_FUNC(PyObject *) PyEval_EvalFrame(PyFrameObject *);"
         ),
         (
             "Include/ceval.h",
             "",
             "PyAPI_FUNC(PyObject *) PyEval_EvalFrameEx(PyFrameObject *f, int exc);"
         ),
         (
             "Include/ceval.h",
             "",
             "PyAPI_FUNC(PyThreadState *) PyEval_SaveThread(void);"
         ),
         (
             "Include/ceval.h",
             "",
             "PyAPI_FUNC(void) PyEval_RestoreThread(PyThreadState *);"
         ),
         (
             "Include/ceval.h",
             "",
             "Py_DEPRECATED(3.9) PyAPI_FUNC(void) PyEval_InitThreads(void);"
         ),
         (
             "Include/ceval.h",
             "",
             "PyAPI_FUNC(void) PyEval_AcquireThread(PyThreadState *tstate);"
         ),
         (
             "Include/ceval.h",
             "",
             "PyAPI_FUNC(void) PyEval_ReleaseThread(PyThreadState *tstate);"
         ),
         (
             "Include/codecs.h",
             "",
             "PyAPI_FUNC(int) PyCodec_Register( PyObject *search_function );"
         ),
         (
             "Include/codecs.h",
             "",
             "PyAPI_FUNC(int) PyCodec_Unregister( PyObject *search_function );"
         ),
         (
             "Include/codecs.h",
             "",
             "PyAPI_FUNC(int) PyCodec_KnownEncoding( const char *encoding );"
         ),
         (
             "Include/codecs.h",
             "",
             "PyAPI_FUNC(PyObject *) PyCodec_Encode( PyObject *object, const char *encoding, const char *errors );"
         ),
         (
             "Include/codecs.h",
             "",
             "PyAPI_FUNC(PyObject *) PyCodec_Decode( PyObject *object, const char *encoding, const char *errors );"
         ),
         (
             "Include/codecs.h",
             "",
             "PyAPI_FUNC(PyObject *) PyCodec_Encoder(const char *encoding);"
         ),
         (
             "Include/codecs.h",
             "",
             "PyAPI_FUNC(PyObject *) PyCodec_Decoder(const char *encoding);"
         ),
         (
             "Include/codecs.h",
             "",
             "PyAPI_FUNC(PyObject *) PyCodec_IncrementalEncoder( const char *encoding, const char *errors);"
         ),
         (
             "Include/codecs.h",
             "",
             "PyAPI_FUNC(PyObject *) PyCodec_IncrementalDecoder( const char *encoding, const char *errors);"
         ),
         (
             "Include/codecs.h",
             "",
             "PyAPI_FUNC(PyObject *) PyCodec_StreamReader( const char *encoding, PyObject *stream, const char *errors);"
         ),
         (
             "Include/codecs.h",
             "",
             "PyAPI_FUNC(PyObject *) PyCodec_StreamWriter( const char *encoding, PyObject *stream, const char *errors);"
         ),
         (
             "Include/codecs.h",
             "",
             "PyAPI_FUNC(int) PyCodec_RegisterError(const char *name, PyObject *error);"
         ),
         (
             "Include/codecs.h",
             "",
             "PyAPI_FUNC(PyObject *) PyCodec_LookupError(const char *name);"
         ),
         (
             "Include/codecs.h",
             "",
             "PyAPI_FUNC(PyObject *) PyCodec_StrictErrors(PyObject *exc);"
         ),
         (
             "Include/codecs.h",
             "",
             "PyAPI_FUNC(PyObject *) PyCodec_IgnoreErrors(PyObject *exc);"
         ),
         (
             "Include/codecs.h",
             "",
             "PyAPI_FUNC(PyObject *) PyCodec_ReplaceErrors(PyObject *exc);"
         ),
         (
             "Include/codecs.h",
             "",
             "PyAPI_FUNC(PyObject *) PyCodec_XMLCharRefReplaceErrors(PyObject *exc);"
         ),
         (
             "Include/codecs.h",
             "",
             "PyAPI_FUNC(PyObject *) PyCodec_BackslashReplaceErrors(PyObject *exc);"
         ),
         (
             "Include/codecs.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03050000)",
             "PyAPI_FUNC(PyObject *) PyCodec_NameReplaceErrors(PyObject *exc);"
         ),
         (
             "Include/codecs.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_DATA(const char *) Py_hexdigits;"
         ),
         ("Include/complexobject.h", "", "PyAPI_DATA(PyTypeObject) PyComplex_Type;"),
         (
             "Include/complexobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyComplex_FromDoubles(double real, double imag);"
         ),
         (
             "Include/complexobject.h",
             "",
             "PyAPI_FUNC(double) PyComplex_RealAsDouble(PyObject *op);"
         ),
         (
             "Include/complexobject.h",
             "",
             "PyAPI_FUNC(double) PyComplex_ImagAsDouble(PyObject *op);"
         ),
         (
             "Include/cpython/abstract.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyObject_CallMethodId( PyObject *obj, _Py_Identifier *name, const char *format, ...);"
         ),
         (
             "Include/cpython/abstract.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyStack_AsDict(PyObject *const *values, PyObject *kwnames);"
         ),
         (
             "Include/cpython/abstract.h",
             "",
             "PyAPI_FUNC(vectorcallfunc) PyVectorcall_Function(PyObject *callable);"
         ),
         (
             "Include/cpython/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyObject_VectorcallDict( PyObject *callable, PyObject *const *args, size_t nargsf, PyObject *kwargs);"
         ),
         (
             "Include/cpython/abstract.h",
             "",
             "PyAPI_FUNC(PyObject *) PyObject_CallOneArg(PyObject *func, PyObject *arg);"
         ),
         (
             "Include/cpython/abstract.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) PyObject_LengthHint(PyObject *o, Py_ssize_t);"
         ),
         (
             "Include/cpython/audit.h",
             "",
             "PyAPI_FUNC(int) PySys_AddAuditHook(Py_AuditHookFunction, void*);"
         ),
         (
             "Include/cpython/bytearrayobject.h",
             "",
             "PyAPI_DATA(char) _PyByteArray_empty_string[];"
         ),
         (
             "Include/cpython/bytesobject.h",
             "",
             "PyAPI_FUNC(int) _PyBytes_Resize(PyObject **, Py_ssize_t);"
         ),
         (
             "Include/cpython/bytesobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyBytes_Join(PyObject *sep, PyObject *iterable);"
         ),
         (
             "Include/cpython/cellobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_DATA(PyTypeObject) PyCell_Type;"
         ),
         (
             "Include/cpython/cellobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyCell_New(PyObject *);"
         ),
         (
             "Include/cpython/cellobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyCell_Get(PyObject *);"
         ),
         (
             "Include/cpython/cellobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyCell_Set(PyObject *, PyObject *);"
         ),
         (
             "Include/cpython/ceval.h",
             "",
             "PyAPI_FUNC(void) PyEval_SetProfile(Py_tracefunc, PyObject *);"
         ),
         (
             "Include/cpython/ceval.h",
             "",
             "PyAPI_FUNC(void) PyEval_SetProfileAllThreads(Py_tracefunc, PyObject *);"
         ),
         (
             "Include/cpython/ceval.h",
             "",
             "PyAPI_FUNC(void) PyEval_SetTrace(Py_tracefunc, PyObject *);"
         ),
         (
             "Include/cpython/ceval.h",
             "",
             "PyAPI_FUNC(void) PyEval_SetTraceAllThreads(Py_tracefunc, PyObject *);"
         ),
         (
             "Include/cpython/ceval.h",
             "",
             "PyAPI_FUNC(int) PyEval_MergeCompilerFlags(PyCompilerFlags *cf);"
         ),
         (
             "Include/cpython/ceval.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyEval_EvalFrameDefault(PyThreadState *tstate, struct _PyInterpreterFrame *f, int exc);"
         ),
         (
             "Include/cpython/ceval.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) PyUnstable_Eval_RequestCodeExtraIndex(freefunc);"
         ),
         (
             "Include/cpython/ceval.h",
             "",
             "PyAPI_FUNC(int) _PyEval_SliceIndex(PyObject *, Py_ssize_t *);"
         ),
         (
             "Include/cpython/ceval.h",
             "",
             "PyAPI_FUNC(int) _PyEval_SliceIndexNotNone(PyObject *, Py_ssize_t *);"
         ),
         (
             "Include/cpython/ceval.h",
             "",
             "PyAPI_FUNC(int) PyUnstable_PerfMapState_Init(void);"
         ),
         (
             "Include/cpython/ceval.h",
             "",
             "PyAPI_FUNC(int) PyUnstable_WritePerfMapEntry( const void *code_addr, unsigned int code_size, const char *entry_name);"
         ),
         (
             "Include/cpython/ceval.h",
             "",
             "PyAPI_FUNC(void) PyUnstable_PerfMapState_Fini(void);"
         ),
         (
             "Include/cpython/ceval.h",
             "",
             "PyAPI_FUNC(int) PyUnstable_CopyPerfMapFile(const char* parent_filename);"
         ),
         (
             "Include/cpython/ceval.h",
             "",
             "PyAPI_FUNC(int) PyUnstable_PerfTrampoline_CompileCode(PyCodeObject *);"
         ),
         (
             "Include/cpython/ceval.h",
             "",
             "PyAPI_FUNC(int) PyUnstable_PerfTrampoline_SetPersistAfterFork(int enable);"
         ),
         (
             "Include/cpython/classobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_DATA(PyTypeObject) PyMethod_Type;"
         ),
         (
             "Include/cpython/classobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyMethod_New(PyObject *, PyObject *);"
         ),
         (
             "Include/cpython/classobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyMethod_Function(PyObject *);"
         ),
         (
             "Include/cpython/classobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyMethod_Self(PyObject *);"
         ),
         (
             "Include/cpython/classobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_DATA(PyTypeObject) PyInstanceMethod_Type;"
         ),
         (
             "Include/cpython/classobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyInstanceMethod_New(PyObject *);"
         ),
         (
             "Include/cpython/classobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyInstanceMethod_Function(PyObject *);"
         ),
         (
             "Include/cpython/code.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_DATA(PyTypeObject) PyCode_Type;"
         ),
         (
             "Include/cpython/code.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyCodeObject *) PyUnstable_Code_New( int, int, int, int, int, PyObject *, PyObject *, PyObject *, PyObject *, PyObject *, PyObject *, PyObject *, PyObject *, PyObject *, int, PyObject *, PyObject *);"
         ),
         (
             "Include/cpython/code.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyCodeObject *) PyUnstable_Code_NewWithPosOnlyArgs( int, int, int, int, int, int, PyObject *, PyObject *, PyObject *, PyObject *, PyObject *, PyObject *, PyObject *, PyObject *, PyObject *, int, PyObject *, PyObject *);"
         ),
         (
             "Include/cpython/code.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyCodeObject *) PyCode_NewEmpty(const char *filename, const char *funcname, int firstlineno);"
         ),
         (
             "Include/cpython/code.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyCode_Addr2Line(PyCodeObject *, int);"
         ),
         (
             "Include/cpython/code.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyCode_Addr2Location(PyCodeObject *, int, int *, int *, int *, int *);"
         ),
         (
             "Include/cpython/code.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyCode_AddWatcher(PyCode_WatchCallback callback);"
         ),
         (
             "Include/cpython/code.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyCode_ClearWatcher(int watcher_id);"
         ),
         (
             "Include/cpython/code.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) _PyCode_CheckLineNumber(int lasti, PyCodeAddressRange *bounds);"
         ),
         (
             "Include/cpython/code.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject*) _PyCode_ConstantKey(PyObject *obj);"
         ),
         (
             "Include/cpython/code.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject*) PyCode_Optimize(PyObject *code, PyObject* consts, PyObject *names, PyObject *lnotab);"
         ),
         (
             "Include/cpython/code.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyUnstable_Code_GetExtra( PyObject *code, Py_ssize_t index, void **extra);"
         ),
         (
             "Include/cpython/code.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyUnstable_Code_SetExtra( PyObject *code, Py_ssize_t index, void *extra);"
         ),
         (
             "Include/cpython/code.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyCode_GetCode(PyCodeObject *code);"
         ),
         (
             "Include/cpython/code.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyCode_GetVarnames(PyCodeObject *code);"
         ),
         (
             "Include/cpython/code.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyCode_GetCellvars(PyCodeObject *code);"
         ),
         (
             "Include/cpython/code.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyCode_GetFreevars(PyCodeObject *code);"
         ),
         (
             "Include/cpython/compile.h",
             "",
             "PyAPI_FUNC(int) PyCompile_OpcodeStackEffect(int opcode, int oparg);"
         ),
         (
             "Include/cpython/compile.h",
             "",
             "PyAPI_FUNC(int) PyCompile_OpcodeStackEffectWithJump(int opcode, int oparg, int jump);"
         ),
         (
             "Include/cpython/complexobject.h",
             "",
             "PyAPI_FUNC(Py_complex) _Py_c_sum(Py_complex, Py_complex);"
         ),
         (
             "Include/cpython/complexobject.h",
             "",
             "PyAPI_FUNC(Py_complex) _Py_c_diff(Py_complex, Py_complex);"
         ),
         (
             "Include/cpython/complexobject.h",
             "",
             "PyAPI_FUNC(Py_complex) _Py_c_neg(Py_complex);"
         ),
         (
             "Include/cpython/complexobject.h",
             "",
             "PyAPI_FUNC(Py_complex) _Py_c_prod(Py_complex, Py_complex);"
         ),
         (
             "Include/cpython/complexobject.h",
             "",
             "PyAPI_FUNC(Py_complex) _Py_c_quot(Py_complex, Py_complex);"
         ),
         (
             "Include/cpython/complexobject.h",
             "",
             "PyAPI_FUNC(Py_complex) _Py_c_pow(Py_complex, Py_complex);"
         ),
         (
             "Include/cpython/complexobject.h",
             "",
             "PyAPI_FUNC(double) _Py_c_abs(Py_complex);"
         ),
         (
             "Include/cpython/complexobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyComplex_FromCComplex(Py_complex);"
         ),
         (
             "Include/cpython/complexobject.h",
             "",
             "PyAPI_FUNC(Py_complex) PyComplex_AsCComplex(PyObject *op);"
         ),
         (
             "Include/cpython/context.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_DATA(PyTypeObject) PyContext_Type;"
         ),
         (
             "Include/cpython/context.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_DATA(PyTypeObject) PyContextVar_Type;"
         ),
         (
             "Include/cpython/context.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_DATA(PyTypeObject) PyContextToken_Type;"
         ),
         (
             "Include/cpython/context.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyContext_New(void);"
         ),
         (
             "Include/cpython/context.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyContext_Copy(PyObject *);"
         ),
         (
             "Include/cpython/context.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyContext_CopyCurrent(void);"
         ),
         (
             "Include/cpython/context.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyContext_Enter(PyObject *);"
         ),
         (
             "Include/cpython/context.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyContext_Exit(PyObject *);"
         ),
         (
             "Include/cpython/context.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyContext_AddWatcher(PyContext_WatchCallback callback);"
         ),
         (
             "Include/cpython/context.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyContext_ClearWatcher(int watcher_id);"
         ),
         (
             "Include/cpython/context.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyContextVar_New( const char *name, PyObject *default_value);"
         ),
         (
             "Include/cpython/context.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyContextVar_Get( PyObject *var, PyObject *default_value, PyObject **value);"
         ),
         (
             "Include/cpython/context.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyContextVar_Set(PyObject *var, PyObject *value);"
         ),
         (
             "Include/cpython/context.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyContextVar_Reset(PyObject *var, PyObject *token);"
         ),
         (
             "Include/cpython/critical_section.h",
             "",
             "PyAPI_FUNC(void) PyCriticalSection_Begin(PyCriticalSection *c, PyObject *op);"
         ),
         (
             "Include/cpython/critical_section.h",
             "",
             "PyAPI_FUNC(void) PyCriticalSection_BeginMutex(PyCriticalSection *c, PyMutex *m);"
         ),
         (
             "Include/cpython/critical_section.h",
             "",
             "PyAPI_FUNC(void) PyCriticalSection_End(PyCriticalSection *c);"
         ),
         (
             "Include/cpython/critical_section.h",
             "",
             "PyAPI_FUNC(void) PyCriticalSection2_Begin(PyCriticalSection2 *c, PyObject *a, PyObject *b);"
         ),
         (
             "Include/cpython/critical_section.h",
             "",
             "PyAPI_FUNC(void) PyCriticalSection2_BeginMutex(PyCriticalSection2 *c, PyMutex *m1, PyMutex *m2);"
         ),
         (
             "Include/cpython/critical_section.h",
             "",
             "PyAPI_FUNC(void) PyCriticalSection2_End(PyCriticalSection2 *c);"
         ),
         (
             "Include/cpython/descrobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyDescr_NewWrapper(PyTypeObject *, struct wrapperbase *, void *);"
         ),
         (
             "Include/cpython/descrobject.h",
             "",
             "PyAPI_FUNC(int) PyDescr_IsData(PyObject *);"
         ),
         (
             "Include/cpython/dictobject.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyDict_GetItem_KnownHash(PyObject *mp, PyObject *key, Py_hash_t hash);"
         ),
         (
             "Include/cpython/dictobject.h",
             "",
             "Py_DEPRECATED(3.14) PyAPI_FUNC(PyObject *) _PyDict_GetItemStringWithError(PyObject *, const char *);"
         ),
         (
             "Include/cpython/dictobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyDict_SetDefault( PyObject *mp, PyObject *key, PyObject *defaultobj);"
         ),
         (
             "Include/cpython/dictobject.h",
             "",
             "PyAPI_FUNC(int) PyDict_SetDefaultRef(PyObject *mp, PyObject *key, PyObject *default_value, PyObject **result);"
         ),
         (
             "Include/cpython/dictobject.h",
             "",
             "PyAPI_FUNC(int) PyDict_ContainsString(PyObject *mp, const char *key);"
         ),
         (
             "Include/cpython/dictobject.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyDict_NewPresized(Py_ssize_t minused);"
         ),
         (
             "Include/cpython/dictobject.h",
             "",
             "PyAPI_FUNC(int) PyDict_Pop(PyObject *dict, PyObject *key, PyObject **result);"
         ),
         (
             "Include/cpython/dictobject.h",
             "",
             "PyAPI_FUNC(int) PyDict_PopString(PyObject *dict, const char *key, PyObject **result);"
         ),
         (
             "Include/cpython/dictobject.h",
             "",
             "Py_DEPRECATED(3.14) PyAPI_FUNC(PyObject *) _PyDict_Pop( PyObject *dict, PyObject *key, PyObject *default_value);"
         ),
         (
             "Include/cpython/dictobject.h",
             "",
             "PyAPI_FUNC(int) PyDict_AddWatcher(PyDict_WatchCallback callback);"
         ),
         (
             "Include/cpython/dictobject.h",
             "",
             "PyAPI_FUNC(int) PyDict_ClearWatcher(int watcher_id);"
         ),
         (
             "Include/cpython/dictobject.h",
             "",
             "PyAPI_FUNC(int) PyDict_Watch(int watcher_id, PyObject* dict);"
         ),
         (
             "Include/cpython/dictobject.h",
             "",
             "PyAPI_FUNC(int) PyDict_Unwatch(int watcher_id, PyObject* dict);"
         ),
         (
             "Include/cpython/fileobject.h",
             "",
             "PyAPI_FUNC(char *) Py_UniversalNewlineFgets(char *, int, FILE*, PyObject *);"
         ),
         (
             "Include/cpython/fileobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyFile_NewStdPrinter(int);"
         ),
         (
             "Include/cpython/fileobject.h",
             "",
             "PyAPI_DATA(PyTypeObject) PyStdPrinter_Type;"
         ),
         (
             "Include/cpython/fileobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyFile_OpenCode(const char *utf8path);"
         ),
         (
             "Include/cpython/fileobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyFile_OpenCodeObject(PyObject *path);"
         ),
         (
             "Include/cpython/fileobject.h",
             "",
             "PyAPI_FUNC(int) PyFile_SetOpenCodeHook(Py_OpenCodeHookFunction hook, void *userData);"
         ),
         (
             "Include/cpython/fileutils.h",
             "",
             "PyAPI_FUNC(FILE*) Py_fopen( PyObject *path, const char *mode);"
         ),
         ("Include/cpython/fileutils.h", "", "PyAPI_FUNC(int) Py_fclose(FILE *file);"),
         (
             "Include/cpython/floatobject.h",
             "",
             "PyAPI_FUNC(int) PyFloat_Pack2(double x, char *p, int le);"
         ),
         (
             "Include/cpython/floatobject.h",
             "",
             "PyAPI_FUNC(int) PyFloat_Pack4(double x, char *p, int le);"
         ),
         (
             "Include/cpython/floatobject.h",
             "",
             "PyAPI_FUNC(int) PyFloat_Pack8(double x, char *p, int le);"
         ),
         (
             "Include/cpython/floatobject.h",
             "",
             "PyAPI_FUNC(double) PyFloat_Unpack2(const char *p, int le);"
         ),
         (
             "Include/cpython/floatobject.h",
             "",
             "PyAPI_FUNC(double) PyFloat_Unpack4(const char *p, int le);"
         ),
         (
             "Include/cpython/floatobject.h",
             "",
             "PyAPI_FUNC(double) PyFloat_Unpack8(const char *p, int le);"
         ),
         (
             "Include/cpython/frameobject.h",
             "",
             "PyAPI_FUNC(PyFrameObject *) PyFrame_New(PyThreadState *, PyCodeObject *, PyObject *, PyObject *);"
         ),
         (
             "Include/cpython/frameobject.h",
             "",
             "PyAPI_FUNC(void) PyFrame_LocalsToFast(PyFrameObject *, int);"
         ),
         (
             "Include/cpython/frameobject.h",
             "",
             "PyAPI_FUNC(int) _PyFrame_IsEntryFrame(PyFrameObject *frame);"
         ),
         (
             "Include/cpython/frameobject.h",
             "",
             "PyAPI_FUNC(int) PyFrame_FastToLocalsWithError(PyFrameObject *f);"
         ),
         (
             "Include/cpython/frameobject.h",
             "",
             "PyAPI_FUNC(void) PyFrame_FastToLocals(PyFrameObject *);"
         ),
         (
             "Include/cpython/funcobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_DATA(PyTypeObject) PyFunction_Type;"
         ),
         (
             "Include/cpython/funcobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyFunction_New(PyObject *, PyObject *);"
         ),
         (
             "Include/cpython/funcobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyFunction_NewWithQualName(PyObject *, PyObject *, PyObject *);"
         ),
         (
             "Include/cpython/funcobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyFunction_GetCode(PyObject *);"
         ),
         (
             "Include/cpython/funcobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyFunction_GetGlobals(PyObject *);"
         ),
         (
             "Include/cpython/funcobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyFunction_GetModule(PyObject *);"
         ),
         (
             "Include/cpython/funcobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyFunction_GetDefaults(PyObject *);"
         ),
         (
             "Include/cpython/funcobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyFunction_SetDefaults(PyObject *, PyObject *);"
         ),
         (
             "Include/cpython/funcobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(void) PyFunction_SetVectorcall(PyFunctionObject *, vectorcallfunc);"
         ),
         (
             "Include/cpython/funcobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyFunction_GetKwDefaults(PyObject *);"
         ),
         (
             "Include/cpython/funcobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyFunction_SetKwDefaults(PyObject *, PyObject *);"
         ),
         (
             "Include/cpython/funcobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyFunction_GetClosure(PyObject *);"
         ),
         (
             "Include/cpython/funcobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyFunction_SetClosure(PyObject *, PyObject *);"
         ),
         (
             "Include/cpython/funcobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyFunction_GetAnnotations(PyObject *);"
         ),
         (
             "Include/cpython/funcobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyFunction_SetAnnotations(PyObject *, PyObject *);"
         ),
         (
             "Include/cpython/funcobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_DATA(PyTypeObject) PyClassMethod_Type;"
         ),
         (
             "Include/cpython/funcobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_DATA(PyTypeObject) PyStaticMethod_Type;"
         ),
         (
             "Include/cpython/funcobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyClassMethod_New(PyObject *);"
         ),
         (
             "Include/cpython/funcobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyStaticMethod_New(PyObject *);"
         ),
         (
             "Include/cpython/funcobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyFunction_AddWatcher(PyFunction_WatchCallback callback);"
         ),
         (
             "Include/cpython/funcobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyFunction_ClearWatcher(int watcher_id);"
         ),
         (
             "Include/cpython/genobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_DATA(PyTypeObject) PyGen_Type;"
         ),
         (
             "Include/cpython/genobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyGen_New(PyFrameObject *);"
         ),
         (
             "Include/cpython/genobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyGen_NewWithQualName(PyFrameObject *, PyObject *name, PyObject *qualname);"
         ),
         (
             "Include/cpython/genobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyCodeObject *) PyGen_GetCode(PyGenObject *gen);"
         ),
         (
             "Include/cpython/genobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_DATA(PyTypeObject) PyCoro_Type;"
         ),
         (
             "Include/cpython/genobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyCoro_New(PyFrameObject *, PyObject *name, PyObject *qualname);"
         ),
         (
             "Include/cpython/genobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_DATA(PyTypeObject) PyAsyncGen_Type;"
         ),
         (
             "Include/cpython/genobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_DATA(PyTypeObject) _PyAsyncGenASend_Type;"
         ),
         (
             "Include/cpython/genobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyAsyncGen_New(PyFrameObject *, PyObject *name, PyObject *qualname);"
         ),
         (
             "Include/cpython/import.h",
             "",
             "PyAPI_DATA(struct _inittab *) PyImport_Inittab;"
         ),
         (
             "Include/cpython/import.h",
             "",
             "PyAPI_FUNC(int) PyImport_ExtendInittab(struct _inittab *newtab);"
         ),
         (
             "Include/cpython/import.h",
             "",
             "PyAPI_DATA(const struct _frozen *) PyImport_FrozenModules;"
         ),
         (
             "Include/cpython/import.h",
             "",
             "PyAPI_FUNC(PyObject*) PyImport_ImportModuleAttr( PyObject *mod_name, PyObject *attr_name);"
         ),
         (
             "Include/cpython/import.h",
             "",
             "PyAPI_FUNC(PyObject*) PyImport_ImportModuleAttrString( const char *mod_name, const char *attr_name);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyStatus) PyStatus_Ok(void);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyStatus) PyStatus_Error(const char *err_msg);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyStatus) PyStatus_NoMemory(void);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyStatus) PyStatus_Exit(int exitcode);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyStatus_IsError(PyStatus err);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyStatus_IsExit(PyStatus err);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyStatus_Exception(PyStatus err);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyStatus) PyWideStringList_Append(PyWideStringList *list, const wchar_t *item);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyStatus) PyWideStringList_Insert(PyWideStringList *list, Py_ssize_t index, const wchar_t *item);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(void) PyPreConfig_InitPythonConfig(PyPreConfig *config);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(void) PyPreConfig_InitIsolatedConfig(PyPreConfig *config);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(void) PyConfig_InitPythonConfig(PyConfig *config);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(void) PyConfig_InitIsolatedConfig(PyConfig *config);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(void) PyConfig_Clear(PyConfig *);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyStatus) PyConfig_SetString( PyConfig *config, wchar_t **config_str, const wchar_t *str);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyStatus) PyConfig_SetBytesString( PyConfig *config, wchar_t **config_str, const char *str);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyStatus) PyConfig_Read(PyConfig *config);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyStatus) PyConfig_SetBytesArgv( PyConfig *config, Py_ssize_t argc, char * const *argv);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyStatus) PyConfig_SetArgv(PyConfig *config, Py_ssize_t argc, wchar_t * const *argv);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyStatus) PyConfig_SetWideStringList(PyConfig *config, PyWideStringList *list, Py_ssize_t length, wchar_t **items);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject*) PyConfig_Get(const char *name);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyConfig_GetInt(const char *name, int *value);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject*) PyConfig_Names(void);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyConfig_Set(const char *name, PyObject *value);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(void) Py_GetArgcArgv(int *argc, wchar_t ***argv);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyInitConfig*) PyInitConfig_Create(void);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(void) PyInitConfig_Free(PyInitConfig *config);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyInitConfig_GetError(PyInitConfig* config, const char **err_msg);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyInitConfig_GetExitCode(PyInitConfig* config, int *exitcode);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyInitConfig_HasOption(PyInitConfig *config, const char *name);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyInitConfig_GetInt(PyInitConfig *config, const char *name, int64_t *value);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyInitConfig_GetStr(PyInitConfig *config, const char *name, char **value);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyInitConfig_GetStrList(PyInitConfig *config, const char *name, size_t *length, char ***items);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(void) PyInitConfig_FreeStrList(size_t length, char **items);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyInitConfig_SetInt(PyInitConfig *config, const char *name, int64_t value);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyInitConfig_SetStr(PyInitConfig *config, const char *name, const char *value);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyInitConfig_SetStrList(PyInitConfig *config, const char *name, size_t length, char * const *items);"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyInitConfig_AddModule(PyInitConfig *config, const char *name, PyObject* (*initfunc)(void));"
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) Py_InitializeFromInitConfig(PyInitConfig *config);"
         ),
         (
             "Include/cpython/listobject.h",
             "",
             "PyAPI_FUNC(int) PyList_Extend(PyObject *self, PyObject *iterable);"
         ),
         (
             "Include/cpython/listobject.h",
             "",
             "PyAPI_FUNC(int) PyList_Clear(PyObject *self);"
         ),
         ("Include/cpython/lock.h", "", "PyAPI_FUNC(void) PyMutex_Lock(PyMutex *m);"),
         ("Include/cpython/lock.h", "", "PyAPI_FUNC(void) PyMutex_Unlock(PyMutex *m);"),
         (
             "Include/cpython/lock.h",
             "",
             "PyAPI_FUNC(int) PyMutex_IsLocked(PyMutex *m);"
         ),
         (
             "Include/cpython/longintrepr.h",
             "!defined(Py_LIMITED_API)",
             "Py_DEPRECATED(3.14) PyAPI_FUNC(PyLongObject*) _PyLong_New(Py_ssize_t);"
         ),
         (
             "Include/cpython/longintrepr.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject*) _PyLong_Copy(PyLongObject *src);"
         ),
         (
             "Include/cpython/longintrepr.h",
             "!defined(Py_LIMITED_API)",
             "Py_DEPRECATED(3.14) PyAPI_FUNC(PyLongObject*) _PyLong_FromDigits( int negative, Py_ssize_t digit_count, digit *digits);"
         ),
         (
             "Include/cpython/longintrepr.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(const PyLongLayout*) PyLong_GetNativeLayout(void);"
         ),
         (
             "Include/cpython/longintrepr.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyLong_Export( PyObject *obj, PyLongExport *export_long);"
         ),
         (
             "Include/cpython/longintrepr.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(void) PyLong_FreeExport( PyLongExport *export_long);"
         ),
         (
             "Include/cpython/longintrepr.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyLongWriter*) PyLongWriter_Create( int negative, Py_ssize_t ndigits, void **digits);"
         ),
         (
             "Include/cpython/longintrepr.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject*) PyLongWriter_Finish(PyLongWriter *writer);"
         ),
         (
             "Include/cpython/longintrepr.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(void) PyLongWriter_Discard(PyLongWriter *writer);"
         ),
         (
             "Include/cpython/longobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyLong_FromUnicodeObject(PyObject *u, int base);"
         ),
         (
             "Include/cpython/longobject.h",
             "",
             "PyAPI_FUNC(int) PyUnstable_Long_IsCompact(const PyLongObject* op);"
         ),
         (
             "Include/cpython/longobject.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) PyUnstable_Long_CompactValue(const PyLongObject* op);"
         ),
         (
             "Include/cpython/longobject.h",
             "",
             "PyAPI_FUNC(int) PyLong_IsPositive(PyObject *obj);"
         ),
         (
             "Include/cpython/longobject.h",
             "",
             "PyAPI_FUNC(int) PyLong_IsNegative(PyObject *obj);"
         ),
         (
             "Include/cpython/longobject.h",
             "",
             "PyAPI_FUNC(int) PyLong_IsZero(PyObject *obj);"
         ),
         (
             "Include/cpython/longobject.h",
             "",
             "PyAPI_FUNC(int) PyLong_GetSign(PyObject *v, int *sign);"
         ),
         (
             "Include/cpython/longobject.h",
             "",
             "Py_DEPRECATED(3.14) PyAPI_FUNC(int) _PyLong_Sign(PyObject *v);"
         ),
         (
             "Include/cpython/longobject.h",
             "",
             "PyAPI_FUNC(int64_t) _PyLong_NumBits(PyObject *v);"
         ),
         (
             "Include/cpython/longobject.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyLong_FromByteArray( const unsigned char* bytes, size_t n, int little_endian, int is_signed);"
         ),
         (
             "Include/cpython/longobject.h",
             "",
             "PyAPI_FUNC(int) _PyLong_AsByteArray(PyLongObject* v, unsigned char* bytes, size_t n, int little_endian, int is_signed, int with_exceptions);"
         ),
         (
             "Include/cpython/longobject.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyLong_GCD(PyObject *, PyObject *);"
         ),
         (
             "Include/cpython/methodobject.h",
             "",
             "PyAPI_DATA(PyTypeObject) PyCMethod_Type;"
         ),
         (
             "Include/cpython/modsupport.h",
             "",
             "PyAPI_FUNC(int) _PyArg_ParseTupleAndKeywordsFast(PyObject *, PyObject *, struct _PyArg_Parser *, ...);"
         ),
         (
             "Include/cpython/monitoring.h",
             "",
             "PyAPI_FUNC(int) PyMonitoring_EnterScope(PyMonitoringState *state_array, uint64_t *version, const uint8_t *event_types, Py_ssize_t length);"
         ),
         (
             "Include/cpython/monitoring.h",
             "",
             "PyAPI_FUNC(int) PyMonitoring_ExitScope(void);"
         ),
         (
             "Include/cpython/monitoring.h",
             "",
             "PyAPI_FUNC(int) _PyMonitoring_FirePyStartEvent(PyMonitoringState *state, PyObject *codelike, int32_t offset);"
         ),
         (
             "Include/cpython/monitoring.h",
             "",
             "PyAPI_FUNC(int) _PyMonitoring_FirePyResumeEvent(PyMonitoringState *state, PyObject *codelike, int32_t offset);"
         ),
         (
             "Include/cpython/monitoring.h",
             "",
             "PyAPI_FUNC(int) _PyMonitoring_FirePyReturnEvent(PyMonitoringState *state, PyObject *codelike, int32_t offset, PyObject *retval);"
         ),
         (
             "Include/cpython/monitoring.h",
             "",
             "PyAPI_FUNC(int) _PyMonitoring_FirePyYieldEvent(PyMonitoringState *state, PyObject *codelike, int32_t offset, PyObject *retval);"
         ),
         (
             "Include/cpython/monitoring.h",
             "",
             "PyAPI_FUNC(int) _PyMonitoring_FireCallEvent(PyMonitoringState *state, PyObject *codelike, int32_t offset, PyObject* callable, PyObject *arg0);"
         ),
         (
             "Include/cpython/monitoring.h",
             "",
             "PyAPI_FUNC(int) _PyMonitoring_FireLineEvent(PyMonitoringState *state, PyObject *codelike, int32_t offset, int lineno);"
         ),
         (
             "Include/cpython/monitoring.h",
             "",
             "PyAPI_FUNC(int) _PyMonitoring_FireJumpEvent(PyMonitoringState *state, PyObject *codelike, int32_t offset, PyObject *target_offset);"
         ),
         (
             "Include/cpython/monitoring.h",
             "",
             "Py_DEPRECATED(3.14) PyAPI_FUNC(int) _PyMonitoring_FireBranchEvent(PyMonitoringState *state, PyObject *codelike, int32_t offset, PyObject *target_offset);"
         ),
         (
             "Include/cpython/monitoring.h",
             "",
             "PyAPI_FUNC(int) _PyMonitoring_FireBranchRightEvent(PyMonitoringState *state, PyObject *codelike, int32_t offset, PyObject *target_offset);"
         ),
         (
             "Include/cpython/monitoring.h",
             "",
             "PyAPI_FUNC(int) _PyMonitoring_FireBranchLeftEvent(PyMonitoringState *state, PyObject *codelike, int32_t offset, PyObject *target_offset);"
         ),
         (
             "Include/cpython/monitoring.h",
             "",
             "PyAPI_FUNC(int) _PyMonitoring_FireCReturnEvent(PyMonitoringState *state, PyObject *codelike, int32_t offset, PyObject *retval);"
         ),
         (
             "Include/cpython/monitoring.h",
             "",
             "PyAPI_FUNC(int) _PyMonitoring_FirePyThrowEvent(PyMonitoringState *state, PyObject *codelike, int32_t offset);"
         ),
         (
             "Include/cpython/monitoring.h",
             "",
             "PyAPI_FUNC(int) _PyMonitoring_FireRaiseEvent(PyMonitoringState *state, PyObject *codelike, int32_t offset);"
         ),
         (
             "Include/cpython/monitoring.h",
             "",
             "PyAPI_FUNC(int) _PyMonitoring_FireReraiseEvent(PyMonitoringState *state, PyObject *codelike, int32_t offset);"
         ),
         (
             "Include/cpython/monitoring.h",
             "",
             "PyAPI_FUNC(int) _PyMonitoring_FireExceptionHandledEvent(PyMonitoringState *state, PyObject *codelike, int32_t offset);"
         ),
         (
             "Include/cpython/monitoring.h",
             "",
             "PyAPI_FUNC(int) _PyMonitoring_FireCRaiseEvent(PyMonitoringState *state, PyObject *codelike, int32_t offset);"
         ),
         (
             "Include/cpython/monitoring.h",
             "",
             "PyAPI_FUNC(int) _PyMonitoring_FirePyUnwindEvent(PyMonitoringState *state, PyObject *codelike, int32_t offset);"
         ),
         (
             "Include/cpython/monitoring.h",
             "",
             "PyAPI_FUNC(int) _PyMonitoring_FireStopIterationEvent(PyMonitoringState *state, PyObject *codelike, int32_t offset, PyObject *value);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(void) _Py_NewReference(PyObject *op);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(void) _Py_NewReferenceNoTotal(PyObject *op);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(void) _Py_ResurrectReference(PyObject *op);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(void) _Py_ForgetReference(PyObject *op);"
         ),
         (
             "Include/cpython/object.h",
             "defined(Py_REF_DEBUG)",
             "PyAPI_FUNC(Py_ssize_t) _Py_GetGlobalRefTotal(void);"
         ),
         (
             "Include/cpython/object.h",
             "defined(Py_REF_DEBUG)",
             "PyAPI_FUNC(Py_ssize_t) _Py_GetLegacyRefTotal(void);"
         ),
         (
             "Include/cpython/object.h",
             "defined(Py_REF_DEBUG)",
             "PyAPI_FUNC(Py_ssize_t) _PyInterpreterState_GetRefTotal(PyInterpreterState *);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(const char *) _PyType_Name(PyTypeObject *);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyType_Lookup(PyTypeObject *, PyObject *);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyType_LookupRef(PyTypeObject *, PyObject *);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(PyObject *) PyType_GetDict(PyTypeObject *);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(int) PyObject_Print(PyObject *, FILE *, int);"
         ),
         ("Include/cpython/object.h", "", "PyAPI_FUNC(void) _Py_BreakPoint(void);"),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(void) _PyObject_Dump(PyObject *);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyObject_GetAttrId(PyObject *, _Py_Identifier *);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(PyObject **) _PyObject_GetDictPtr(PyObject *);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(void) PyObject_CallFinalizer(PyObject *);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(int) PyObject_CallFinalizerFromDealloc(PyObject *);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(void) PyUnstable_Object_ClearWeakRefsNoCallbacks(PyObject *);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyObject_GenericGetAttrWithDict(PyObject *, PyObject *, PyObject *, int);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(int) _PyObject_GenericSetAttrWithDict(PyObject *, PyObject *, PyObject *, PyObject *);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyObject_FunctionStr(PyObject *);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(void) _Py_NO_RETURN _PyObject_AssertFailed( PyObject *obj, const char *expr, const char *msg, const char *file, int line, const char *function);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(void) _PyTrash_thread_deposit_object(PyThreadState *tstate, PyObject *op);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(void) _PyTrash_thread_destroy_chain(PyThreadState *tstate);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(int) _Py_ReachedRecursionLimitWithMargin(PyThreadState *tstate, int margin_count);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(void *) PyObject_GetItemData(PyObject *obj);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(int) PyObject_VisitManagedDict(PyObject *obj, visitproc visit, void *arg);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(int) _PyObject_SetManagedDict(PyObject *obj, PyObject *new_dict);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(void) PyObject_ClearManagedDict(PyObject *obj);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(int) PyType_AddWatcher(PyType_WatchCallback callback);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(int) PyType_ClearWatcher(int watcher_id);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(int) PyType_Watch(int watcher_id, PyObject *type);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(int) PyType_Unwatch(int watcher_id, PyObject *type);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(int) PyUnstable_Type_AssignVersionTag(PyTypeObject *type);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(int) PyRefTracer_SetTracer(PyRefTracer tracer, void *data);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(PyRefTracer) PyRefTracer_GetTracer(void**);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(int) PyUnstable_Object_EnableDeferredRefcount(PyObject *);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(int) PyUnstable_Object_IsUniqueReferencedTemporary(PyObject *);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(int) PyUnstable_IsImmortal(PyObject *);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(int) PyUnstable_TryIncRef(PyObject *);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(void) PyUnstable_EnableTryIncRef(PyObject *);"
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyAPI_FUNC(int) PyUnstable_Object_IsUniquelyReferenced(PyObject *);"
         ),
         (
             "Include/cpython/objimpl.h",
             "",
             "PyAPI_FUNC(void) PyObject_GetArenaAllocator(PyObjectArenaAllocator *allocator);"
         ),
         (
             "Include/cpython/objimpl.h",
             "",
             "PyAPI_FUNC(void) PyObject_SetArenaAllocator(PyObjectArenaAllocator *allocator);"
         ),
         (
             "Include/cpython/objimpl.h",
             "",
             "PyAPI_FUNC(int) PyObject_IS_GC(PyObject *obj);"
         ),
         (
             "Include/cpython/objimpl.h",
             "",
             "PyAPI_FUNC(int) PyType_SUPPORTS_WEAKREFS(PyTypeObject *type);"
         ),
         (
             "Include/cpython/objimpl.h",
             "",
             "PyAPI_FUNC(PyObject **) PyObject_GET_WEAKREFS_LISTPTR(PyObject *op);"
         ),
         (
             "Include/cpython/objimpl.h",
             "",
             "PyAPI_FUNC(PyObject *) PyUnstable_Object_GC_NewWithExtraData(PyTypeObject *, size_t);"
         ),
         (
             "Include/cpython/objimpl.h",
             "",
             "PyAPI_FUNC(void) PyUnstable_GC_VisitObjects(gcvisitobjects_t callback, void* arg);"
         ),
         (
             "Include/cpython/odictobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_DATA(PyTypeObject) PyODict_Type;"
         ),
         (
             "Include/cpython/odictobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_DATA(PyTypeObject) PyODictIter_Type;"
         ),
         (
             "Include/cpython/odictobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_DATA(PyTypeObject) PyODictKeys_Type;"
         ),
         (
             "Include/cpython/odictobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_DATA(PyTypeObject) PyODictItems_Type;"
         ),
         (
             "Include/cpython/odictobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_DATA(PyTypeObject) PyODictValues_Type;"
         ),
         (
             "Include/cpython/odictobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyODict_New(void);"
         ),
         (
             "Include/cpython/odictobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyODict_SetItem(PyObject *od, PyObject *key, PyObject *item);"
         ),
         (
             "Include/cpython/odictobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyODict_DelItem(PyObject *od, PyObject *key);"
         ),
         (
             "Include/cpython/picklebufobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_DATA(PyTypeObject) PyPickleBuffer_Type;"
         ),
         (
             "Include/cpython/picklebufobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyPickleBuffer_FromObject(PyObject *);"
         ),
         (
             "Include/cpython/picklebufobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(const Py_buffer *) PyPickleBuffer_GetBuffer(PyObject *);"
         ),
         (
             "Include/cpython/picklebufobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyPickleBuffer_Release(PyObject *);"
         ),
         (
             "Include/cpython/pthread_stubs.h",
             "",
             "PyAPI_FUNC(int) pthread_mutex_init(pthread_mutex_t *restrict mutex, const pthread_mutexattr_t *restrict attr);"
         ),
         (
             "Include/cpython/pthread_stubs.h",
             "",
             "PyAPI_FUNC(int) pthread_mutex_destroy(pthread_mutex_t *mutex);"
         ),
         (
             "Include/cpython/pthread_stubs.h",
             "",
             "PyAPI_FUNC(int) pthread_mutex_trylock(pthread_mutex_t *mutex);"
         ),
         (
             "Include/cpython/pthread_stubs.h",
             "",
             "PyAPI_FUNC(int) pthread_mutex_lock(pthread_mutex_t *mutex);"
         ),
         (
             "Include/cpython/pthread_stubs.h",
             "",
             "PyAPI_FUNC(int) pthread_mutex_unlock(pthread_mutex_t *mutex);"
         ),
         (
             "Include/cpython/pthread_stubs.h",
             "",
             "PyAPI_FUNC(int) pthread_cond_init(pthread_cond_t *restrict cond, const pthread_condattr_t *restrict attr);"
         ),
         (
             "Include/cpython/pthread_stubs.h",
             "",
             "PyAPI_FUNC(int) pthread_cond_destroy(pthread_cond_t *cond);"
         ),
         (
             "Include/cpython/pthread_stubs.h",
             "",
             "PyAPI_FUNC(int) pthread_cond_wait(pthread_cond_t *restrict cond, pthread_mutex_t *restrict mutex);"
         ),
         (
             "Include/cpython/pthread_stubs.h",
             "",
             "PyAPI_FUNC(int) pthread_cond_timedwait(pthread_cond_t *restrict cond, pthread_mutex_t *restrict mutex, const struct timespec *restrict abstime);"
         ),
         (
             "Include/cpython/pthread_stubs.h",
             "",
             "PyAPI_FUNC(int) pthread_cond_signal(pthread_cond_t *cond);"
         ),
         (
             "Include/cpython/pthread_stubs.h",
             "",
             "PyAPI_FUNC(int) pthread_condattr_init(pthread_condattr_t *attr);"
         ),
         (
             "Include/cpython/pthread_stubs.h",
             "",
             "PyAPI_FUNC(int) pthread_condattr_setclock( pthread_condattr_t *attr, clockid_t clock_id);"
         ),
         (
             "Include/cpython/pthread_stubs.h",
             "",
             "PyAPI_FUNC(int) pthread_create(pthread_t *restrict thread, const pthread_attr_t *restrict attr, void *(*start_routine)(void *), void *restrict arg);"
         ),
         (
             "Include/cpython/pthread_stubs.h",
             "",
             "PyAPI_FUNC(int) pthread_detach(pthread_t thread);"
         ),
         (
             "Include/cpython/pthread_stubs.h",
             "",
             "PyAPI_FUNC(int) pthread_join(pthread_t thread, void** value_ptr);"
         ),
         (
             "Include/cpython/pthread_stubs.h",
             "",
             "PyAPI_FUNC(pthread_t) pthread_self(void);"
         ),
         (
             "Include/cpython/pthread_stubs.h",
             "",
             "PyAPI_FUNC(int) pthread_exit(void *retval) __attribute__ ((__noreturn__));"
         ),
         (
             "Include/cpython/pthread_stubs.h",
             "",
             "PyAPI_FUNC(int) pthread_attr_init(pthread_attr_t *attr);"
         ),
         (
             "Include/cpython/pthread_stubs.h",
             "",
             "PyAPI_FUNC(int) pthread_attr_setstacksize(pthread_attr_t *attr, size_t stacksize);"
         ),
         (
             "Include/cpython/pthread_stubs.h",
             "",
             "PyAPI_FUNC(int) pthread_attr_destroy(pthread_attr_t *attr);"
         ),
         (
             "Include/cpython/pthread_stubs.h",
             "",
             "PyAPI_FUNC(int) pthread_key_create(pthread_key_t *key, void (*destr_function)(void *));"
         ),
         (
             "Include/cpython/pthread_stubs.h",
             "",
             "PyAPI_FUNC(int) pthread_key_delete(pthread_key_t key);"
         ),
         (
             "Include/cpython/pthread_stubs.h",
             "",
             "PyAPI_FUNC(void *) pthread_getspecific(pthread_key_t key);"
         ),
         (
             "Include/cpython/pthread_stubs.h",
             "",
             "PyAPI_FUNC(int) pthread_setspecific(pthread_key_t key, const void *value);"
         ),
         (
             "Include/cpython/pyctype.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_DATA(const unsigned int) _Py_ctype_table[256];"
         ),
         (
             "Include/cpython/pyctype.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_DATA(const unsigned char) _Py_ctype_tolower[256];"
         ),
         (
             "Include/cpython/pyctype.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_DATA(const unsigned char) _Py_ctype_toupper[256];"
         ),
         (
             "Include/cpython/pydebug.h",
             "!defined(Py_LIMITED_API)",
             "Py_DEPRECATED(3.12) PyAPI_DATA(int) Py_DebugFlag;"
         ),
         (
             "Include/cpython/pydebug.h",
             "!defined(Py_LIMITED_API)",
             "Py_DEPRECATED(3.12) PyAPI_DATA(int) Py_VerboseFlag;"
         ),
         (
             "Include/cpython/pydebug.h",
             "!defined(Py_LIMITED_API)",
             "Py_DEPRECATED(3.12) PyAPI_DATA(int) Py_QuietFlag;"
         ),
         (
             "Include/cpython/pydebug.h",
             "!defined(Py_LIMITED_API)",
             "Py_DEPRECATED(3.12) PyAPI_DATA(int) Py_InteractiveFlag;"
         ),
         (
             "Include/cpython/pydebug.h",
             "!defined(Py_LIMITED_API)",
             "Py_DEPRECATED(3.12) PyAPI_DATA(int) Py_InspectFlag;"
         ),
         (
             "Include/cpython/pydebug.h",
             "!defined(Py_LIMITED_API)",
             "Py_DEPRECATED(3.12) PyAPI_DATA(int) Py_OptimizeFlag;"
         ),
         (
             "Include/cpython/pydebug.h",
             "!defined(Py_LIMITED_API)",
             "Py_DEPRECATED(3.12) PyAPI_DATA(int) Py_NoSiteFlag;"
         ),
         (
             "Include/cpython/pydebug.h",
             "!defined(Py_LIMITED_API)",
             "Py_DEPRECATED(3.12) PyAPI_DATA(int) Py_BytesWarningFlag;"
         ),
         (
             "Include/cpython/pydebug.h",
             "!defined(Py_LIMITED_API)",
             "Py_DEPRECATED(3.12) PyAPI_DATA(int) Py_FrozenFlag;"
         ),
         (
             "Include/cpython/pydebug.h",
             "!defined(Py_LIMITED_API)",
             "Py_DEPRECATED(3.12) PyAPI_DATA(int) Py_IgnoreEnvironmentFlag;"
         ),
         (
             "Include/cpython/pydebug.h",
             "!defined(Py_LIMITED_API)",
             "Py_DEPRECATED(3.12) PyAPI_DATA(int) Py_DontWriteBytecodeFlag;"
         ),
         (
             "Include/cpython/pydebug.h",
             "!defined(Py_LIMITED_API)",
             "Py_DEPRECATED(3.12) PyAPI_DATA(int) Py_NoUserSiteDirectory;"
         ),
         (
             "Include/cpython/pydebug.h",
             "!defined(Py_LIMITED_API)",
             "Py_DEPRECATED(3.12) PyAPI_DATA(int) Py_UnbufferedStdioFlag;"
         ),
         (
             "Include/cpython/pydebug.h",
             "!defined(Py_LIMITED_API)",
             "Py_DEPRECATED(3.12) PyAPI_DATA(int) Py_HashRandomizationFlag;"
         ),
         (
             "Include/cpython/pydebug.h",
             "!defined(Py_LIMITED_API)",
             "Py_DEPRECATED(3.12) PyAPI_DATA(int) Py_IsolatedFlag;"
         ),
         (
             "Include/cpython/pydebug.h",
             "!defined(Py_LIMITED_API) && defined(MS_WINDOWS)",
             "Py_DEPRECATED(3.12) PyAPI_DATA(int) Py_LegacyWindowsFSEncodingFlag;"
         ),
         (
             "Include/cpython/pydebug.h",
             "!defined(Py_LIMITED_API) && defined(MS_WINDOWS)",
             "Py_DEPRECATED(3.12) PyAPI_DATA(int) Py_LegacyWindowsStdioFlag;"
         ),
         (
             "Include/cpython/pydebug.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(char*) Py_GETENV(const char *name);"
         ),
         (
             "Include/cpython/pyerrors.h",
             "",
             "PyAPI_FUNC(void) _PyErr_ChainExceptions1(PyObject *);"
         ),
         (
             "Include/cpython/pyerrors.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnstable_Exc_PrepReraiseStar( PyObject *orig, PyObject *excs);"
         ),
         (
             "Include/cpython/pyerrors.h",
             "",
             "PyAPI_FUNC(int) PySignal_SetWakeupFd(int fd);"
         ),
         (
             "Include/cpython/pyerrors.h",
             "",
             "PyAPI_FUNC(void) PyErr_SyntaxLocationObject( PyObject *filename, int lineno, int col_offset);"
         ),
         (
             "Include/cpython/pyerrors.h",
             "",
             "PyAPI_FUNC(void) PyErr_RangedSyntaxLocationObject( PyObject *filename, int lineno, int col_offset, int end_lineno, int end_col_offset);"
         ),
         (
             "Include/cpython/pyerrors.h",
             "",
             "PyAPI_FUNC(PyObject *) PyErr_ProgramTextObject( PyObject *filename, int lineno);"
         ),
         (
             "Include/cpython/pyerrors.h",
             "",
             "PyAPI_FUNC(void) _Py_NO_RETURN _Py_FatalErrorFunc( const char *func, const char *message);"
         ),
         (
             "Include/cpython/pyerrors.h",
             "",
             "PyAPI_FUNC(void) PyErr_FormatUnraisable(const char *, ...);"
         ),
         (
             "Include/cpython/pyerrors.h",
             "",
             "PyAPI_DATA(PyObject *) PyExc_PythonFinalizationError;"
         ),
         ("Include/cpython/pyframe.h", "", "PyAPI_DATA(PyTypeObject) PyFrame_Type;"),
         (
             "Include/cpython/pyframe.h",
             "",
             "PyAPI_DATA(PyTypeObject) PyFrameLocalsProxy_Type;"
         ),
         (
             "Include/cpython/pyframe.h",
             "",
             "PyAPI_FUNC(PyFrameObject *) PyFrame_GetBack(PyFrameObject *frame);"
         ),
         (
             "Include/cpython/pyframe.h",
             "",
             "PyAPI_FUNC(PyObject *) PyFrame_GetLocals(PyFrameObject *frame);"
         ),
         (
             "Include/cpython/pyframe.h",
             "",
             "PyAPI_FUNC(PyObject *) PyFrame_GetGlobals(PyFrameObject *frame);"
         ),
         (
             "Include/cpython/pyframe.h",
             "",
             "PyAPI_FUNC(PyObject *) PyFrame_GetBuiltins(PyFrameObject *frame);"
         ),
         (
             "Include/cpython/pyframe.h",
             "",
             "PyAPI_FUNC(PyObject *) PyFrame_GetGenerator(PyFrameObject *frame);"
         ),
         (
             "Include/cpython/pyframe.h",
             "",
             "PyAPI_FUNC(int) PyFrame_GetLasti(PyFrameObject *frame);"
         ),
         (
             "Include/cpython/pyframe.h",
             "",
             "PyAPI_FUNC(PyObject*) PyFrame_GetVar(PyFrameObject *frame, PyObject *name);"
         ),
         (
             "Include/cpython/pyframe.h",
             "",
             "PyAPI_FUNC(PyObject*) PyFrame_GetVarString(PyFrameObject *frame, const char *name);"
         ),
         (
             "Include/cpython/pyframe.h",
             "",
             "PyAPI_FUNC(PyObject *) PyUnstable_InterpreterFrame_GetCode(struct _PyInterpreterFrame *frame);"
         ),
         (
             "Include/cpython/pyframe.h",
             "",
             "PyAPI_FUNC(int) PyUnstable_InterpreterFrame_GetLasti(struct _PyInterpreterFrame *frame);"
         ),
         (
             "Include/cpython/pyframe.h",
             "",
             "PyAPI_FUNC(int) PyUnstable_InterpreterFrame_GetLine(struct _PyInterpreterFrame *frame);"
         ),
         (
             "Include/cpython/pyframe.h",
             "",
             "PyAPI_DATA(const PyTypeObject *) const PyUnstable_ExecutableKinds[PyUnstable_EXECUTABLE_KINDS+1];"
         ),
         (
             "Include/cpython/pyhash.h",
             "",
             "PyAPI_FUNC(Py_hash_t) _Py_HashDouble(PyObject *, double);"
         ),
         (
             "Include/cpython/pyhash.h",
             "",
             "PyAPI_FUNC(PyHash_FuncDef*) PyHash_GetFuncDef(void);"
         ),
         (
             "Include/cpython/pyhash.h",
             "",
             "PyAPI_FUNC(Py_hash_t) Py_HashPointer(const void *ptr);"
         ),
         (
             "Include/cpython/pyhash.h",
             "",
             "PyAPI_FUNC(Py_hash_t) PyObject_GenericHash(PyObject *);"
         ),
         (
             "Include/cpython/pyhash.h",
             "",
             "PyAPI_FUNC(Py_hash_t) Py_HashBuffer(const void *ptr, Py_ssize_t len);"
         ),
         (
             "Include/cpython/pylifecycle.h",
             "",
             "PyAPI_FUNC(int) Py_FrozenMain(int argc, char **argv);"
         ),
         (
             "Include/cpython/pylifecycle.h",
             "",
             "PyAPI_FUNC(PyStatus) Py_PreInitialize( const PyPreConfig *src_config);"
         ),
         (
             "Include/cpython/pylifecycle.h",
             "",
             "PyAPI_FUNC(PyStatus) Py_PreInitializeFromBytesArgs( const PyPreConfig *src_config, Py_ssize_t argc, char **argv);"
         ),
         (
             "Include/cpython/pylifecycle.h",
             "",
             "PyAPI_FUNC(PyStatus) Py_PreInitializeFromArgs( const PyPreConfig *src_config, Py_ssize_t argc, wchar_t **argv);"
         ),
         (
             "Include/cpython/pylifecycle.h",
             "",
             "PyAPI_FUNC(PyStatus) Py_InitializeFromConfig( const PyConfig *config);"
         ),
         ("Include/cpython/pylifecycle.h", "", "PyAPI_FUNC(int) Py_RunMain(void);"),
         (
             "Include/cpython/pylifecycle.h",
             "",
             "PyAPI_FUNC(void) _Py_NO_RETURN Py_ExitStatusException(PyStatus err);"
         ),
         (
             "Include/cpython/pylifecycle.h",
             "",
             "PyAPI_FUNC(int) Py_FdIsInteractive(FILE *, const char *);"
         ),
         (
             "Include/cpython/pylifecycle.h",
             "",
             "PyAPI_FUNC(PyStatus) Py_NewInterpreterFromConfig( PyThreadState **tstate_p, const PyInterpreterConfig *config);"
         ),
         (
             "Include/cpython/pylifecycle.h",
             "",
             "PyAPI_FUNC(int) PyUnstable_AtExit( PyInterpreterState *, atexit_datacallbackfunc, void *);"
         ),
         (
             "Include/cpython/pymem.h",
             "",
             "PyAPI_FUNC(void) PyMem_GetAllocator(PyMemAllocatorDomain domain, PyMemAllocatorEx *allocator);"
         ),
         (
             "Include/cpython/pymem.h",
             "",
             "PyAPI_FUNC(void) PyMem_SetAllocator(PyMemAllocatorDomain domain, PyMemAllocatorEx *allocator);"
         ),
         (
             "Include/cpython/pymem.h",
             "",
             "PyAPI_FUNC(void) PyMem_SetupDebugHooks(void);"
         ),
         (
             "Include/cpython/pystate.h",
             "",
             "PyAPI_FUNC(int) _PyInterpreterState_RequiresIDRef(PyInterpreterState *);"
         ),
         (
             "Include/cpython/pystate.h",
             "",
             "PyAPI_FUNC(void) _PyInterpreterState_RequireIDRef(PyInterpreterState *, int);"
         ),
         (
             "Include/cpython/pystate.h",
             "",
             "PyAPI_FUNC(PyThreadState *) PyThreadState_GetUnchecked(void);"
         ),
         (
             "Include/cpython/pystate.h",
             "",
             "PyAPI_FUNC(void) PyThreadState_EnterTracing(PyThreadState *tstate);"
         ),
         (
             "Include/cpython/pystate.h",
             "",
             "PyAPI_FUNC(void) PyThreadState_LeaveTracing(PyThreadState *tstate);"
         ),
         ("Include/cpython/pystate.h", "", "PyAPI_FUNC(int) PyGILState_Check(void);"),
         (
             "Include/cpython/pystate.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyThread_CurrentFrames(void);"
         ),
         (
             "Include/cpython/pystate.h",
             "",
             "PyAPI_FUNC(int) PyUnstable_ThreadState_SetStackProtection( PyThreadState *tstate, void *stack_start_addr, size_t stack_size);"
         ),
         (
             "Include/cpython/pystate.h",
             "",
             "PyAPI_FUNC(void) PyUnstable_ThreadState_ResetStackProtection( PyThreadState *tstate);"
         ),
         (
             "Include/cpython/pystate.h",
             "",
             "PyAPI_FUNC(PyInterpreterState *) PyInterpreterState_Main(void);"
         ),
         (
             "Include/cpython/pystate.h",
             "",
             "PyAPI_FUNC(PyInterpreterState *) PyInterpreterState_Head(void);"
         ),
         (
             "Include/cpython/pystate.h",
             "",
             "PyAPI_FUNC(PyInterpreterState *) PyInterpreterState_Next(PyInterpreterState *);"
         ),
         (
             "Include/cpython/pystate.h",
             "",
             "PyAPI_FUNC(PyThreadState *) PyInterpreterState_ThreadHead(PyInterpreterState *);"
         ),
         (
             "Include/cpython/pystate.h",
             "",
             "PyAPI_FUNC(PyThreadState *) PyThreadState_Next(PyThreadState *);"
         ),
         (
             "Include/cpython/pystate.h",
             "",
             "PyAPI_FUNC(void) PyThreadState_DeleteCurrent(void);"
         ),
         (
             "Include/cpython/pystate.h",
             "",
             "PyAPI_FUNC(_PyFrameEvalFunction) _PyInterpreterState_GetEvalFrameFunc( PyInterpreterState *interp);"
         ),
         (
             "Include/cpython/pystate.h",
             "",
             "PyAPI_FUNC(void) _PyInterpreterState_SetEvalFrameFunc( PyInterpreterState *interp, _PyFrameEvalFunction eval_frame);"
         ),
         ("Include/cpython/pystats.h", "", "PyAPI_DATA(PyStats*) _Py_stats;"),
         (
             "Include/cpython/pythonrun.h",
             "",
             "PyAPI_FUNC(int) PyRun_SimpleStringFlags(const char *, PyCompilerFlags *);"
         ),
         (
             "Include/cpython/pythonrun.h",
             "",
             "PyAPI_FUNC(int) PyRun_AnyFileExFlags( FILE *fp, const char *filename, int closeit, PyCompilerFlags *flags);"
         ),
         (
             "Include/cpython/pythonrun.h",
             "",
             "PyAPI_FUNC(int) PyRun_SimpleFileExFlags( FILE *fp, const char *filename, int closeit, PyCompilerFlags *flags);"
         ),
         (
             "Include/cpython/pythonrun.h",
             "",
             "PyAPI_FUNC(int) PyRun_InteractiveOneFlags( FILE *fp, const char *filename, PyCompilerFlags *flags);"
         ),
         (
             "Include/cpython/pythonrun.h",
             "",
             "PyAPI_FUNC(int) PyRun_InteractiveOneObject( FILE *fp, PyObject *filename, PyCompilerFlags *flags);"
         ),
         (
             "Include/cpython/pythonrun.h",
             "",
             "PyAPI_FUNC(int) PyRun_InteractiveLoopFlags( FILE *fp, const char *filename, PyCompilerFlags *flags);"
         ),
         (
             "Include/cpython/pythonrun.h",
             "",
             "PyAPI_FUNC(PyObject *) PyRun_StringFlags(const char *, int, PyObject *, PyObject *, PyCompilerFlags *);"
         ),
         (
             "Include/cpython/pythonrun.h",
             "",
             "PyAPI_FUNC(PyObject *) PyRun_FileExFlags( FILE *fp, const char *filename, int start, PyObject *globals, PyObject *locals, int closeit, PyCompilerFlags *flags);"
         ),
         (
             "Include/cpython/pythonrun.h",
             "",
             "PyAPI_FUNC(PyObject *) Py_CompileStringExFlags( const char *str, const char *filename, int start, PyCompilerFlags *flags, int optimize);"
         ),
         (
             "Include/cpython/pythonrun.h",
             "",
             "PyAPI_FUNC(PyObject *) Py_CompileStringObject( const char *str, PyObject *filename, int start, PyCompilerFlags *flags, int optimize);"
         ),
         (
             "Include/cpython/pythonrun.h",
             "",
             "PyAPI_FUNC(PyObject *) PyRun_String(const char *str, int s, PyObject *g, PyObject *l);"
         ),
         (
             "Include/cpython/pythonrun.h",
             "",
             "PyAPI_FUNC(int) PyRun_AnyFile(FILE *fp, const char *name);"
         ),
         (
             "Include/cpython/pythonrun.h",
             "",
             "PyAPI_FUNC(int) PyRun_AnyFileEx(FILE *fp, const char *name, int closeit);"
         ),
         (
             "Include/cpython/pythonrun.h",
             "",
             "PyAPI_FUNC(int) PyRun_AnyFileFlags(FILE *, const char *, PyCompilerFlags *);"
         ),
         (
             "Include/cpython/pythonrun.h",
             "",
             "PyAPI_FUNC(int) PyRun_SimpleString(const char *s);"
         ),
         (
             "Include/cpython/pythonrun.h",
             "",
             "PyAPI_FUNC(int) PyRun_SimpleFile(FILE *f, const char *p);"
         ),
         (
             "Include/cpython/pythonrun.h",
             "",
             "PyAPI_FUNC(int) PyRun_SimpleFileEx(FILE *f, const char *p, int c);"
         ),
         (
             "Include/cpython/pythonrun.h",
             "",
             "PyAPI_FUNC(int) PyRun_InteractiveOne(FILE *f, const char *p);"
         ),
         (
             "Include/cpython/pythonrun.h",
             "",
             "PyAPI_FUNC(int) PyRun_InteractiveLoop(FILE *f, const char *p);"
         ),
         (
             "Include/cpython/pythonrun.h",
             "",
             "PyAPI_FUNC(PyObject *) PyRun_File(FILE *fp, const char *p, int s, PyObject *g, PyObject *l);"
         ),
         (
             "Include/cpython/pythonrun.h",
             "",
             "PyAPI_FUNC(PyObject *) PyRun_FileEx(FILE *fp, const char *p, int s, PyObject *g, PyObject *l, int c);"
         ),
         (
             "Include/cpython/pythonrun.h",
             "",
             "PyAPI_FUNC(PyObject *) PyRun_FileFlags(FILE *fp, const char *p, int s, PyObject *g, PyObject *l, PyCompilerFlags *flags);"
         ),
         (
             "Include/cpython/pythonrun.h",
             "",
             "PyAPI_FUNC(char *) PyOS_Readline(FILE *, FILE *, const char *);"
         ),
         (
             "Include/cpython/pythonrun.h",
             "",
             "PyAPI_DATA(char) *(*PyOS_ReadlineFunctionPointer)(FILE *, FILE *, const char *);"
         ),
         (
             "Include/cpython/pythread.h",
             "",
             "PyAPI_DATA(const long long) PY_TIMEOUT_MAX;"
         ),
         (
             "Include/cpython/pytime.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(double) PyTime_AsSecondsDouble(PyTime_t t);"
         ),
         (
             "Include/cpython/pytime.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyTime_Monotonic(PyTime_t *result);"
         ),
         (
             "Include/cpython/pytime.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyTime_PerfCounter(PyTime_t *result);"
         ),
         (
             "Include/cpython/pytime.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyTime_Time(PyTime_t *result);"
         ),
         (
             "Include/cpython/pytime.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyTime_MonotonicRaw(PyTime_t *result);"
         ),
         (
             "Include/cpython/pytime.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyTime_PerfCounterRaw(PyTime_t *result);"
         ),
         (
             "Include/cpython/pytime.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyTime_TimeRaw(PyTime_t *result);"
         ),
         (
             "Include/cpython/tracemalloc.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyTraceMalloc_Track( unsigned int domain, uintptr_t ptr, size_t size);"
         ),
         (
             "Include/cpython/tracemalloc.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyTraceMalloc_Untrack( unsigned int domain, uintptr_t ptr);"
         ),
         (
             "Include/cpython/tupleobject.h",
             "",
             "PyAPI_FUNC(int) _PyTuple_Resize(PyObject **, Py_ssize_t);"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) PyUnicode_KIND(PyObject *op);"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(void*) PyUnicode_DATA(PyObject *op);"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_New( Py_ssize_t size, Py_UCS4 maxchar );"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) PyUnicode_CopyCharacters( PyObject *to, Py_ssize_t to_start, PyObject *from, Py_ssize_t from_start, Py_ssize_t how_many );"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) PyUnicode_Fill( PyObject *unicode, Py_ssize_t start, Py_ssize_t length, Py_UCS4 fill_char );"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_FromKindAndData( int kind, const void *buffer, Py_ssize_t size);"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyUnicodeWriter*) PyUnicodeWriter_Create(Py_ssize_t length);"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(void) PyUnicodeWriter_Discard(PyUnicodeWriter *writer);"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicodeWriter_Finish(PyUnicodeWriter *writer);"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) PyUnicodeWriter_WriteChar( PyUnicodeWriter *writer, Py_UCS4 ch);"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) PyUnicodeWriter_WriteUTF8( PyUnicodeWriter *writer, const char *str, Py_ssize_t size);"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) PyUnicodeWriter_WriteASCII( PyUnicodeWriter *writer, const char *str, Py_ssize_t size);"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) PyUnicodeWriter_WriteWideChar( PyUnicodeWriter *writer, const wchar_t *str, Py_ssize_t size);"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) PyUnicodeWriter_WriteUCS4( PyUnicodeWriter *writer, Py_UCS4 *str, Py_ssize_t size);"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) PyUnicodeWriter_WriteStr( PyUnicodeWriter *writer, PyObject *obj);"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) PyUnicodeWriter_WriteRepr( PyUnicodeWriter *writer, PyObject *obj);"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) PyUnicodeWriter_WriteSubstring( PyUnicodeWriter *writer, PyObject *str, Py_ssize_t start, Py_ssize_t end);"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) PyUnicodeWriter_Format( PyUnicodeWriter *writer, const char *format, ...);"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) PyUnicodeWriter_DecodeUTF8Stateful( PyUnicodeWriter *writer, const char *string, Py_ssize_t length, const char *errors, Py_ssize_t *consumed);"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(void) _PyUnicodeWriter_Init( _PyUnicodeWriter *writer);"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) _PyUnicodeWriter_PrepareInternal( _PyUnicodeWriter *writer, Py_ssize_t length, Py_UCS4 maxchar);"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) _PyUnicodeWriter_PrepareKindInternal( _PyUnicodeWriter *writer, int kind);"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) _PyUnicodeWriter_WriteChar( _PyUnicodeWriter *writer, Py_UCS4 ch);"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) _PyUnicodeWriter_WriteStr( _PyUnicodeWriter *writer, PyObject *str);"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) _PyUnicodeWriter_WriteSubstring( _PyUnicodeWriter *writer, PyObject *str, Py_ssize_t start, Py_ssize_t end);"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) _PyUnicodeWriter_WriteASCIIString( _PyUnicodeWriter *writer, const char *str, Py_ssize_t len);"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) _PyUnicodeWriter_WriteLatin1String( _PyUnicodeWriter *writer, const char *str, Py_ssize_t len);"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyUnicodeWriter_Finish( _PyUnicodeWriter *writer);"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(void) _PyUnicodeWriter_Dealloc( _PyUnicodeWriter *writer);"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(const char *) PyUnicode_AsUTF8(PyObject *unicode);"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) _PyUnicode_IsLowercase( Py_UCS4 ch );"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) _PyUnicode_IsUppercase( Py_UCS4 ch );"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) _PyUnicode_IsTitlecase( Py_UCS4 ch );"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) _PyUnicode_IsWhitespace( const Py_UCS4 ch );"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) _PyUnicode_IsLinebreak( const Py_UCS4 ch );"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(Py_UCS4) _PyUnicode_ToLowercase( Py_UCS4 ch );"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(Py_UCS4) _PyUnicode_ToUppercase( Py_UCS4 ch );"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(Py_UCS4) _PyUnicode_ToTitlecase( Py_UCS4 ch );"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) _PyUnicode_ToDecimalDigit( Py_UCS4 ch );"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) _PyUnicode_ToDigit( Py_UCS4 ch );"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(double) _PyUnicode_ToNumeric( Py_UCS4 ch );"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) _PyUnicode_IsDecimalDigit( Py_UCS4 ch );"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) _PyUnicode_IsDigit( Py_UCS4 ch );"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) _PyUnicode_IsNumeric( Py_UCS4 ch );"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) _PyUnicode_IsPrintable( Py_UCS4 ch );"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) _PyUnicode_IsAlpha( Py_UCS4 ch );"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_DATA(const unsigned char) _Py_ascii_whitespace[];"
         ),
         (
             "Include/cpython/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyUnicode_FromId(_Py_Identifier*);"
         ),
         (
             "Include/cpython/warnings.h",
             "",
             "PyAPI_FUNC(int) PyErr_WarnExplicitObject( PyObject *category, PyObject *message, PyObject *filename, int lineno, PyObject *module, PyObject *registry);"
         ),
         (
             "Include/cpython/warnings.h",
             "",
             "PyAPI_FUNC(int) PyErr_WarnExplicitFormat( PyObject *category, const char *filename, int lineno, const char *module, PyObject *registry, const char *format, ...);"
         ),
         (
             "Include/cpython/weakrefobject.h",
             "",
             "PyAPI_FUNC(void) _PyWeakref_ClearRef(PyWeakReference *self);"
         ),
         (
             "Include/cpython/weakrefobject.h",
             "",
             "PyAPI_FUNC(int) PyWeakref_IsDead(PyObject *ref);"
         ),
         (
             "Include/descrobject.h",
             "",
             "PyAPI_DATA(PyTypeObject) PyClassMethodDescr_Type;"
         ),
         ("Include/descrobject.h", "", "PyAPI_DATA(PyTypeObject) PyGetSetDescr_Type;"),
         ("Include/descrobject.h", "", "PyAPI_DATA(PyTypeObject) PyMemberDescr_Type;"),
         ("Include/descrobject.h", "", "PyAPI_DATA(PyTypeObject) PyMethodDescr_Type;"),
         ("Include/descrobject.h", "", "PyAPI_DATA(PyTypeObject) PyWrapperDescr_Type;"),
         ("Include/descrobject.h", "", "PyAPI_DATA(PyTypeObject) PyDictProxy_Type;"),
         ("Include/descrobject.h", "", "PyAPI_DATA(PyTypeObject) PyProperty_Type;"),
         (
             "Include/descrobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyDescr_NewMethod(PyTypeObject *, PyMethodDef *);"
         ),
         (
             "Include/descrobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyDescr_NewClassMethod(PyTypeObject *, PyMethodDef *);"
         ),
         (
             "Include/descrobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyDescr_NewMember(PyTypeObject *, PyMemberDef *);"
         ),
         (
             "Include/descrobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyDescr_NewGetSet(PyTypeObject *, PyGetSetDef *);"
         ),
         (
             "Include/descrobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyDictProxy_New(PyObject *);"
         ),
         (
             "Include/descrobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyWrapper_New(PyObject *, PyObject *);"
         ),
         (
             "Include/descrobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyMember_GetOne(const char *, PyMemberDef *);"
         ),
         (
             "Include/descrobject.h",
             "",
             "PyAPI_FUNC(int) PyMember_SetOne(char *, PyMemberDef *, PyObject *);"
         ),
         ("Include/dictobject.h", "", "PyAPI_DATA(PyTypeObject) PyDict_Type;"),
         ("Include/dictobject.h", "", "PyAPI_FUNC(PyObject *) PyDict_New(void);"),
         (
             "Include/dictobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyDict_GetItem(PyObject *mp, PyObject *key);"
         ),
         (
             "Include/dictobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyDict_GetItemWithError(PyObject *mp, PyObject *key);"
         ),
         (
             "Include/dictobject.h",
             "",
             "PyAPI_FUNC(int) PyDict_SetItem(PyObject *mp, PyObject *key, PyObject *item);"
         ),
         (
             "Include/dictobject.h",
             "",
             "PyAPI_FUNC(int) PyDict_DelItem(PyObject *mp, PyObject *key);"
         ),
         ("Include/dictobject.h", "", "PyAPI_FUNC(void) PyDict_Clear(PyObject *mp);"),
         (
             "Include/dictobject.h",
             "",
             "PyAPI_FUNC(int) PyDict_Next( PyObject *mp, Py_ssize_t *pos, PyObject **key, PyObject **value);"
         ),
         (
             "Include/dictobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyDict_Keys(PyObject *mp);"
         ),
         (
             "Include/dictobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyDict_Values(PyObject *mp);"
         ),
         (
             "Include/dictobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyDict_Items(PyObject *mp);"
         ),
         (
             "Include/dictobject.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) PyDict_Size(PyObject *mp);"
         ),
         (
             "Include/dictobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyDict_Copy(PyObject *mp);"
         ),
         (
             "Include/dictobject.h",
             "",
             "PyAPI_FUNC(int) PyDict_Contains(PyObject *mp, PyObject *key);"
         ),
         (
             "Include/dictobject.h",
             "",
             "PyAPI_FUNC(int) PyDict_Update(PyObject *mp, PyObject *other);"
         ),
         (
             "Include/dictobject.h",
             "",
             "PyAPI_FUNC(int) PyDict_Merge(PyObject *mp, PyObject *other, int override);"
         ),
         (
             "Include/dictobject.h",
             "",
             "PyAPI_FUNC(int) PyDict_MergeFromSeq2(PyObject *d, PyObject *seq2, int override);"
         ),
         (
             "Include/dictobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyDict_GetItemString(PyObject *dp, const char *key);"
         ),
         (
             "Include/dictobject.h",
             "",
             "PyAPI_FUNC(int) PyDict_SetItemString(PyObject *dp, const char *key, PyObject *item);"
         ),
         (
             "Include/dictobject.h",
             "",
             "PyAPI_FUNC(int) PyDict_DelItemString(PyObject *dp, const char *key);"
         ),
         (
             "Include/dictobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030D0000)",
             "PyAPI_FUNC(int) PyDict_GetItemRef(PyObject *mp, PyObject *key, PyObject **result);"
         ),
         (
             "Include/dictobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030D0000)",
             "PyAPI_FUNC(int) PyDict_GetItemStringRef(PyObject *mp, const char *key, PyObject **result);"
         ),
         (
             "Include/dictobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030A0000)",
             "PyAPI_FUNC(PyObject *) PyObject_GenericGetDict(PyObject *, void *);"
         ),
         ("Include/dictobject.h", "", "PyAPI_DATA(PyTypeObject) PyDictKeys_Type;"),
         ("Include/dictobject.h", "", "PyAPI_DATA(PyTypeObject) PyDictValues_Type;"),
         ("Include/dictobject.h", "", "PyAPI_DATA(PyTypeObject) PyDictItems_Type;"),
         ("Include/dictobject.h", "", "PyAPI_DATA(PyTypeObject) PyDictIterKey_Type;"),
         ("Include/dictobject.h", "", "PyAPI_DATA(PyTypeObject) PyDictIterValue_Type;"),
         ("Include/dictobject.h", "", "PyAPI_DATA(PyTypeObject) PyDictIterItem_Type;"),
         (
             "Include/dictobject.h",
             "",
             "PyAPI_DATA(PyTypeObject) PyDictRevIterKey_Type;"
         ),
         (
             "Include/dictobject.h",
             "",
             "PyAPI_DATA(PyTypeObject) PyDictRevIterItem_Type;"
         ),
         (
             "Include/dictobject.h",
             "",
             "PyAPI_DATA(PyTypeObject) PyDictRevIterValue_Type;"
         ),
         ("Include/enumobject.h", "", "PyAPI_DATA(PyTypeObject) PyEnum_Type;"),
         ("Include/enumobject.h", "", "PyAPI_DATA(PyTypeObject) PyReversed_Type;"),
         (
             "Include/fileobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyFile_FromFd(int, const char *, const char *, int, const char *, const char *, const char *, int);"
         ),
         (
             "Include/fileobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyFile_GetLine(PyObject *, int);"
         ),
         (
             "Include/fileobject.h",
             "",
             "PyAPI_FUNC(int) PyFile_WriteObject(PyObject *, PyObject *, int);"
         ),
         (
             "Include/fileobject.h",
             "",
             "PyAPI_FUNC(int) PyFile_WriteString(const char *, PyObject *);"
         ),
         (
             "Include/fileobject.h",
             "",
             "PyAPI_FUNC(int) PyObject_AsFileDescriptor(PyObject *);"
         ),
         (
             "Include/fileobject.h",
             "",
             "Py_DEPRECATED(3.12) PyAPI_DATA(const char *) Py_FileSystemDefaultEncoding;"
         ),
         (
             "Include/fileobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03060000)",
             "Py_DEPRECATED(3.12) PyAPI_DATA(const char *) Py_FileSystemDefaultEncodeErrors;"
         ),
         (
             "Include/fileobject.h",
             "",
             "Py_DEPRECATED(3.12) PyAPI_DATA(int) Py_HasFileSystemDefaultEncoding;"
         ),
         (
             "Include/fileobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03070000)",
             "Py_DEPRECATED(3.12) PyAPI_DATA(int) Py_UTF8Mode;"
         ),
         (
             "Include/fileutils.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03050000)",
             "PyAPI_FUNC(wchar_t *) Py_DecodeLocale( const char *arg, size_t *size);"
         ),
         (
             "Include/fileutils.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03050000)",
             "PyAPI_FUNC(char*) Py_EncodeLocale( const wchar_t *text, size_t *error_pos);"
         ),
         ("Include/floatobject.h", "", "PyAPI_DATA(PyTypeObject) PyFloat_Type;"),
         ("Include/floatobject.h", "", "PyAPI_FUNC(double) PyFloat_GetMax(void);"),
         ("Include/floatobject.h", "", "PyAPI_FUNC(double) PyFloat_GetMin(void);"),
         ("Include/floatobject.h", "", "PyAPI_FUNC(PyObject*) PyFloat_GetInfo(void);"),
         (
             "Include/floatobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyFloat_FromString(PyObject*);"
         ),
         (
             "Include/floatobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyFloat_FromDouble(double);"
         ),
         (
             "Include/floatobject.h",
             "",
             "PyAPI_FUNC(double) PyFloat_AsDouble(PyObject*);"
         ),
         (
             "Include/genericaliasobject.h",
             "",
             "PyAPI_FUNC(PyObject *) Py_GenericAlias(PyObject *, PyObject *);"
         ),
         (
             "Include/genericaliasobject.h",
             "",
             "PyAPI_DATA(PyTypeObject) Py_GenericAliasType;"
         ),
         ("Include/import.h", "", "PyAPI_FUNC(long) PyImport_GetMagicNumber(void);"),
         (
             "Include/import.h",
             "",
             "PyAPI_FUNC(const char *) PyImport_GetMagicTag(void);"
         ),
         (
             "Include/import.h",
             "",
             "PyAPI_FUNC(PyObject *) PyImport_ExecCodeModule( const char *name, PyObject *co );"
         ),
         (
             "Include/import.h",
             "",
             "PyAPI_FUNC(PyObject *) PyImport_ExecCodeModuleEx( const char *name, PyObject *co, const char *pathname );"
         ),
         (
             "Include/import.h",
             "",
             "PyAPI_FUNC(PyObject *) PyImport_ExecCodeModuleWithPathnames( const char *name, PyObject *co, const char *pathname, const char *cpathname );"
         ),
         (
             "Include/import.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_FUNC(PyObject *) PyImport_ExecCodeModuleObject( PyObject *name, PyObject *co, PyObject *pathname, PyObject *cpathname );"
         ),
         (
             "Include/import.h",
             "",
             "PyAPI_FUNC(PyObject *) PyImport_GetModuleDict(void);"
         ),
         (
             "Include/import.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03070000)",
             "PyAPI_FUNC(PyObject *) PyImport_GetModule(PyObject *name);"
         ),
         (
             "Include/import.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_FUNC(PyObject *) PyImport_AddModuleObject( PyObject *name );"
         ),
         (
             "Include/import.h",
             "",
             "PyAPI_FUNC(PyObject *) PyImport_AddModule( const char *name );"
         ),
         (
             "Include/import.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030d0000)",
             "PyAPI_FUNC(PyObject *) PyImport_AddModuleRef( const char *name );"
         ),
         (
             "Include/import.h",
             "",
             "PyAPI_FUNC(PyObject *) PyImport_ImportModule( const char *name );"
         ),
         (
             "Include/import.h",
             "",
             "Py_DEPRECATED(3.13) PyAPI_FUNC(PyObject *) PyImport_ImportModuleNoBlock( const char *name );"
         ),
         (
             "Include/import.h",
             "",
             "PyAPI_FUNC(PyObject *) PyImport_ImportModuleLevel( const char *name, PyObject *globals, PyObject *locals, PyObject *fromlist, int level );"
         ),
         (
             "Include/import.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03050000)",
             "PyAPI_FUNC(PyObject *) PyImport_ImportModuleLevelObject( PyObject *name, PyObject *globals, PyObject *locals, PyObject *fromlist, int level );"
         ),
         (
             "Include/import.h",
             "",
             "PyAPI_FUNC(PyObject *) PyImport_GetImporter(PyObject *path);"
         ),
         (
             "Include/import.h",
             "",
             "PyAPI_FUNC(PyObject *) PyImport_Import(PyObject *name);"
         ),
         (
             "Include/import.h",
             "",
             "PyAPI_FUNC(PyObject *) PyImport_ReloadModule(PyObject *m);"
         ),
         (
             "Include/import.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_FUNC(int) PyImport_ImportFrozenModuleObject( PyObject *name );"
         ),
         (
             "Include/import.h",
             "",
             "PyAPI_FUNC(int) PyImport_ImportFrozenModule( const char *name );"
         ),
         (
             "Include/import.h",
             "",
             "PyAPI_FUNC(int) PyImport_AppendInittab( const char *name, PyObject* (*initfunc)(void) );"
         ),
         (
             "Include/internal/mimalloc/mimalloc/internal.h",
             "",
             "extern mi_abandoned_pool_t _mi_abandoned_default;"
         ),
         (
             "Include/internal/mimalloc/mimalloc/internal.h",
             "",
             "extern const mi_heap_t _mi_heap_empty;"
         ),
         (
             "Include/internal/mimalloc/mimalloc/internal.h",
             "",
             "extern mi_heap_t _mi_heap_main;"
         ),
         (
             "Include/internal/mimalloc/mimalloc/internal.h",
             "(!MI_TRACK_ENABLED && defined(_WIN32) && (defined(_M_IX86) || defined(_M_X64)))",
             "extern bool _mi_cpu_has_fsrm;"
         ),
         (
             "Include/internal/mimalloc/mimalloc/prim.h",
             "",
             "extern bool _mi_process_is_initialized;"
         ),
         (
             "Include/internal/mimalloc/mimalloc/prim.h",
             "!defined(MI_TLS_SLOT) && !defined(MI_TLS_PTHREAD_SLOT_OFS) && defined(MI_TLS_PTHREAD)",
             "extern pthread_key_t _mi_heap_default_key;"
         ),
         (
             "Include/internal/pycore_abstract.h",
             "",
             "extern int _PyObject_HasLen(PyObject *o);"
         ),
         (
             "Include/internal/pycore_abstract.h",
             "",
             "extern Py_ssize_t _PySequence_IterSearch(PyObject *seq, PyObject *obj, int operation);"
         ),
         (
             "Include/internal/pycore_abstract.h",
             "",
             "extern int _PyObject_RealIsInstance(PyObject *inst, PyObject *cls);"
         ),
         (
             "Include/internal/pycore_abstract.h",
             "",
             "extern int _PyObject_RealIsSubclass(PyObject *derived, PyObject *cls);"
         ),
         (
             "Include/internal/pycore_abstract.h",
             "",
             "PyAPI_FUNC(int) _Py_convert_optional_to_ssize_t(PyObject *, void *);"
         ),
         (
             "Include/internal/pycore_abstract.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyNumber_Index(PyObject *o);"
         ),
         ("Include/internal/pycore_ast.h", "", "extern int _PyAST_Validate(mod_ty);"),
         (
             "Include/internal/pycore_ast.h",
             "",
             "extern PyObject* _PyAST_ExprAsUnicode(expr_ty);"
         ),
         (
             "Include/internal/pycore_ast.h",
             "",
             "extern PyObject* _PyAST_GetDocString(asdl_stmt_seq *);"
         ),
         (
             "Include/internal/pycore_atexit.h",
             "",
             "PyAPI_FUNC(int) _Py_AtExit( PyInterpreterState *interp, atexit_datacallbackfunc func, void *data);"
         ),
         (
             "Include/internal/pycore_audit.h",
             "",
             "extern int _PySys_Audit( PyThreadState *tstate, const char *event, const char *argFormat, ...);"
         ),
         (
             "Include/internal/pycore_audit.h",
             "",
             "extern void _PySys_ClearAuditHooks(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_bytes_methods.h",
             "!defined(Py_LIMITED_API)",
             "extern PyObject* _Py_bytes_isspace(const char *cptr, Py_ssize_t len);"
         ),
         (
             "Include/internal/pycore_bytes_methods.h",
             "!defined(Py_LIMITED_API)",
             "extern PyObject* _Py_bytes_isalpha(const char *cptr, Py_ssize_t len);"
         ),
         (
             "Include/internal/pycore_bytes_methods.h",
             "!defined(Py_LIMITED_API)",
             "extern PyObject* _Py_bytes_isalnum(const char *cptr, Py_ssize_t len);"
         ),
         (
             "Include/internal/pycore_bytes_methods.h",
             "!defined(Py_LIMITED_API)",
             "extern PyObject* _Py_bytes_isascii(const char *cptr, Py_ssize_t len);"
         ),
         (
             "Include/internal/pycore_bytes_methods.h",
             "!defined(Py_LIMITED_API)",
             "extern PyObject* _Py_bytes_isdigit(const char *cptr, Py_ssize_t len);"
         ),
         (
             "Include/internal/pycore_bytes_methods.h",
             "!defined(Py_LIMITED_API)",
             "extern PyObject* _Py_bytes_islower(const char *cptr, Py_ssize_t len);"
         ),
         (
             "Include/internal/pycore_bytes_methods.h",
             "!defined(Py_LIMITED_API)",
             "extern PyObject* _Py_bytes_isupper(const char *cptr, Py_ssize_t len);"
         ),
         (
             "Include/internal/pycore_bytes_methods.h",
             "!defined(Py_LIMITED_API)",
             "extern PyObject* _Py_bytes_istitle(const char *cptr, Py_ssize_t len);"
         ),
         (
             "Include/internal/pycore_bytes_methods.h",
             "!defined(Py_LIMITED_API)",
             "extern void _Py_bytes_lower(char *result, const char *cptr, Py_ssize_t len);"
         ),
         (
             "Include/internal/pycore_bytes_methods.h",
             "!defined(Py_LIMITED_API)",
             "extern void _Py_bytes_upper(char *result, const char *cptr, Py_ssize_t len);"
         ),
         (
             "Include/internal/pycore_bytes_methods.h",
             "!defined(Py_LIMITED_API)",
             "extern void _Py_bytes_title(char *result, const char *s, Py_ssize_t len);"
         ),
         (
             "Include/internal/pycore_bytes_methods.h",
             "!defined(Py_LIMITED_API)",
             "extern void _Py_bytes_capitalize(char *result, const char *s, Py_ssize_t len);"
         ),
         (
             "Include/internal/pycore_bytes_methods.h",
             "!defined(Py_LIMITED_API)",
             "extern void _Py_bytes_swapcase(char *result, const char *s, Py_ssize_t len);"
         ),
         (
             "Include/internal/pycore_bytes_methods.h",
             "!defined(Py_LIMITED_API)",
             "extern PyObject *_Py_bytes_find(const char *str, Py_ssize_t len, PyObject *sub, Py_ssize_t start, Py_ssize_t end);"
         ),
         (
             "Include/internal/pycore_bytes_methods.h",
             "!defined(Py_LIMITED_API)",
             "extern PyObject *_Py_bytes_index(const char *str, Py_ssize_t len, PyObject *sub, Py_ssize_t start, Py_ssize_t end);"
         ),
         (
             "Include/internal/pycore_bytes_methods.h",
             "!defined(Py_LIMITED_API)",
             "extern PyObject *_Py_bytes_rfind(const char *str, Py_ssize_t len, PyObject *sub, Py_ssize_t start, Py_ssize_t end);"
         ),
         (
             "Include/internal/pycore_bytes_methods.h",
             "!defined(Py_LIMITED_API)",
             "extern PyObject *_Py_bytes_rindex(const char *str, Py_ssize_t len, PyObject *sub, Py_ssize_t start, Py_ssize_t end);"
         ),
         (
             "Include/internal/pycore_bytes_methods.h",
             "!defined(Py_LIMITED_API)",
             "extern PyObject *_Py_bytes_count(const char *str, Py_ssize_t len, PyObject *sub, Py_ssize_t start, Py_ssize_t end);"
         ),
         (
             "Include/internal/pycore_bytes_methods.h",
             "!defined(Py_LIMITED_API)",
             "extern int _Py_bytes_contains(const char *str, Py_ssize_t len, PyObject *arg);"
         ),
         (
             "Include/internal/pycore_bytes_methods.h",
             "!defined(Py_LIMITED_API)",
             "extern PyObject *_Py_bytes_startswith(const char *str, Py_ssize_t len, PyObject *subobj, Py_ssize_t start, Py_ssize_t end);"
         ),
         (
             "Include/internal/pycore_bytes_methods.h",
             "!defined(Py_LIMITED_API)",
             "extern PyObject *_Py_bytes_endswith(const char *str, Py_ssize_t len, PyObject *subobj, Py_ssize_t start, Py_ssize_t end);"
         ),
         (
             "Include/internal/pycore_bytes_methods.h",
             "!defined(Py_LIMITED_API)",
             "extern PyObject* _Py_bytes_maketrans(Py_buffer *frm, Py_buffer *to);"
         ),
         (
             "Include/internal/pycore_bytesobject.h",
             "",
             "extern PyObject* _PyBytes_FormatEx( const char *format, Py_ssize_t format_len, PyObject *args, int use_bytearray);"
         ),
         (
             "Include/internal/pycore_bytesobject.h",
             "",
             "extern PyObject* _PyBytes_FromHex( PyObject *string, int use_bytearray);"
         ),
         (
             "Include/internal/pycore_bytesobject.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyBytes_DecodeEscape2(const char *, Py_ssize_t, const char *, int *, const char **);"
         ),
         (
             "Include/internal/pycore_bytesobject.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) _PyBytes_Find(const char *haystack, Py_ssize_t len_haystack, const char *needle, Py_ssize_t len_needle, Py_ssize_t offset);"
         ),
         (
             "Include/internal/pycore_bytesobject.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) _PyBytes_ReverseFind(const char *haystack, Py_ssize_t len_haystack, const char *needle, Py_ssize_t len_needle, Py_ssize_t offset);"
         ),
         (
             "Include/internal/pycore_bytesobject.h",
             "",
             "PyAPI_FUNC(void) _PyBytes_Repeat(char* dest, Py_ssize_t len_dest, const char* src, Py_ssize_t len_src);"
         ),
         (
             "Include/internal/pycore_bytesobject.h",
             "",
             "PyAPI_FUNC(void) _PyBytesWriter_Init(_PyBytesWriter *writer);"
         ),
         (
             "Include/internal/pycore_bytesobject.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyBytesWriter_Finish(_PyBytesWriter *writer, void *str);"
         ),
         (
             "Include/internal/pycore_bytesobject.h",
             "",
             "PyAPI_FUNC(void) _PyBytesWriter_Dealloc(_PyBytesWriter *writer);"
         ),
         (
             "Include/internal/pycore_bytesobject.h",
             "",
             "PyAPI_FUNC(void*) _PyBytesWriter_Alloc(_PyBytesWriter *writer, Py_ssize_t size);"
         ),
         (
             "Include/internal/pycore_bytesobject.h",
             "",
             "PyAPI_FUNC(void*) _PyBytesWriter_Prepare(_PyBytesWriter *writer, void *str, Py_ssize_t size);"
         ),
         (
             "Include/internal/pycore_bytesobject.h",
             "",
             "PyAPI_FUNC(void*) _PyBytesWriter_Resize(_PyBytesWriter *writer, void *str, Py_ssize_t size);"
         ),
         (
             "Include/internal/pycore_bytesobject.h",
             "",
             "PyAPI_FUNC(void*) _PyBytesWriter_WriteBytes(_PyBytesWriter *writer, void *str, const void *bytes, Py_ssize_t size);"
         ),
         (
             "Include/internal/pycore_call.h",
             "",
             "PyAPI_FUNC(PyObject*) _Py_CheckFunctionResult( PyThreadState *tstate, PyObject *callable, PyObject *result, const char *where);"
         ),
         (
             "Include/internal/pycore_call.h",
             "",
             "extern PyObject* _PyObject_Call_Prepend( PyThreadState *tstate, PyObject *callable, PyObject *obj, PyObject *args, PyObject *kwargs);"
         ),
         (
             "Include/internal/pycore_call.h",
             "",
             "extern PyObject* _PyObject_VectorcallDictTstate( PyThreadState *tstate, PyObject *callable, PyObject *const *args, size_t nargsf, PyObject *kwargs);"
         ),
         (
             "Include/internal/pycore_call.h",
             "",
             "extern PyObject* _PyObject_Call( PyThreadState *tstate, PyObject *callable, PyObject *args, PyObject *kwargs);"
         ),
         (
             "Include/internal/pycore_call.h",
             "",
             "extern PyObject * _PyObject_CallMethodFormat( PyThreadState *tstate, PyObject *callable, const char *format, ...);"
         ),
         (
             "Include/internal/pycore_call.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyObject_CallMethod( PyObject *obj, PyObject *name, const char *format, ...);"
         ),
         (
             "Include/internal/pycore_call.h",
             "",
             "extern PyObject* _PyObject_CallMethodIdObjArgs( PyObject *obj, _Py_Identifier *name, ...);"
         ),
         (
             "Include/internal/pycore_call.h",
             "",
             "extern PyObject *_PyObject_VectorcallPrepend( PyThreadState *tstate, PyObject *callable, PyObject *arg, PyObject *const *args, size_t nargsf, PyObject *kwnames);"
         ),
         (
             "Include/internal/pycore_call.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyObject_MakeTpCall( PyThreadState *tstate, PyObject *callable, PyObject *const *args, Py_ssize_t nargs, PyObject *keywords);"
         ),
         (
             "Include/internal/pycore_call.h",
             "",
             "extern void _PyStack_UnpackDict_Free( PyObject *const *stack, Py_ssize_t nargs, PyObject *kwnames);"
         ),
         (
             "Include/internal/pycore_call.h",
             "",
             "extern void _PyStack_UnpackDict_FreeNoDecRef( PyObject *const *stack, PyObject *kwnames);"
         ),
         (
             "Include/internal/pycore_capsule.h",
             "",
             "PyAPI_FUNC(int) _PyCapsule_SetTraverse(PyObject *op, traverseproc traverse_func, inquiry clear_func);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(int) _PyEval_SetProfile(PyThreadState *tstate, Py_tracefunc func, PyObject *arg);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern int _PyEval_SetProfileAllThreads(PyInterpreterState *interp, Py_tracefunc func, PyObject *arg);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern int _PyEval_SetTrace(PyThreadState *tstate, Py_tracefunc func, PyObject *arg);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern int _PyEval_SetTraceAllThreads(PyInterpreterState *interp, Py_tracefunc func, PyObject *arg);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern int _PyEval_SetOpcodeTrace(PyFrameObject *f, bool enable);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyEval_GetBuiltin(PyObject *);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern PyObject* _PyEval_GetBuiltinId(_Py_Identifier *);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern void _PyEval_SetSwitchInterval(unsigned long microseconds);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern unsigned long _PyEval_GetSwitchInterval(void);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(int) _PyEval_MakePendingCalls(PyThreadState *);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern void _Py_FinishPendingCalls(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern void _PyEval_InitState(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern void _PyEval_SignalReceived(void);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(_Py_add_pending_call_result) _PyEval_AddPendingCall( PyInterpreterState *interp, _Py_pending_call_func func, void *arg, int flags);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "defined(HAVE_FORK)",
             "extern PyStatus _PyEval_ReInitThreads(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern PyObject* _PyEval_CallTracing(PyObject *func, PyObject *args);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern PyObject* _PyEval_GetAsyncGenFirstiter(void);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern PyObject* _PyEval_GetAsyncGenFinalizer(void);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern int _PyEval_SetAsyncGenFirstiter(PyObject *);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern int _PyEval_SetAsyncGenFinalizer(PyObject *);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern int _PyEval_GetCoroutineOriginTrackingDepth(void);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern int _PyEval_SetCoroutineOriginTrackingDepth(int depth);"
         ),
         ("Include/internal/pycore_ceval.h", "", "extern void _PyEval_Fini(void);"),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern PyObject* _PyEval_GetBuiltins(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern int _PyPerfTrampoline_SetCallbacks(_PyPerf_Callbacks *);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern void _PyPerfTrampoline_GetCallbacks(_PyPerf_Callbacks *);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern int _PyPerfTrampoline_Init(int activate);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern int _PyPerfTrampoline_Fini(void);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern int _PyIsPerfTrampolineActive(void);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern PyStatus _PyPerfTrampoline_AfterFork_Child(void);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "defined(PY_HAVE_PERF_TRAMPOLINE)",
             "extern _PyPerf_Callbacks _Py_perfmap_callbacks;"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "defined(PY_HAVE_PERF_TRAMPOLINE)",
             "extern _PyPerf_Callbacks _Py_perfmap_jit_callbacks;"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern int _PyEval_ThreadsInitialized(void);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern void _PyEval_InitGIL(PyThreadState *tstate, int own_gil);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern void _PyEval_FiniGIL(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern void _PyEval_AcquireLock(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern void _PyEval_ReleaseLock(PyInterpreterState *, PyThreadState *, int final_release);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "defined(Py_GIL_DISABLED)",
             "extern int _PyEval_EnableGILTransient(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "defined(Py_GIL_DISABLED)",
             "extern int _PyEval_EnableGILPermanent(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "defined(Py_GIL_DISABLED)",
             "extern int _PyEval_DisableGIL(PyThreadState *state);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern void _PyEval_DeactivateOpCache(void);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(int) _Py_CheckRecursiveCall( PyThreadState *tstate, const char *where);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(void) _Py_InitializeRecursionLimits(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern _PyInterpreterFrame* _PyEval_GetFrame(void);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern PyObject * _PyEval_GetGlobalsFromRunningMain(PyThreadState *);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern int _PyEval_EnsureBuiltins( PyThreadState *, PyObject *, PyObject **p_builtins);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern int _PyEval_EnsureBuiltinsWithModule( PyThreadState *, PyObject *, PyObject **p_builtins);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(PyObject *)_Py_MakeCoro(PyFunctionObject *func);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(int) _Py_HandlePending(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "extern PyObject * _PyEval_GetFrameLocals(void);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_DATA(const binaryfunc) _PyEval_BinaryOps[];"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_DATA(const conversion_func) _PyEval_ConversionFuncs[];"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_DATA(const _Py_SpecialMethod) _Py_SpecialMethods[];"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_DATA(const size_t) _Py_FunctionAttributeOffsets[];"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(int) _PyEval_CheckExceptStarTypeValid(PyThreadState *tstate, PyObject* right);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(int) _PyEval_CheckExceptTypeValid(PyThreadState *tstate, PyObject* right);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(int) _PyEval_ExceptionGroupMatch(_PyInterpreterFrame *, PyObject* exc_value, PyObject *match_type, PyObject **match, PyObject **rest);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(void) _PyEval_FormatAwaitableError(PyThreadState *tstate, PyTypeObject *type, int oparg);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(void) _PyEval_FormatExcCheckArg(PyThreadState *tstate, PyObject *exc, const char *format_str, PyObject *obj);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(void) _PyEval_FormatExcUnbound(PyThreadState *tstate, PyCodeObject *co, int oparg);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(void) _PyEval_FormatKwargsError(PyThreadState *tstate, PyObject *func, PyObject *kwargs);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyEval_ImportFrom(PyThreadState *, PyObject *, PyObject *);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyEval_ImportName(PyThreadState *, _PyInterpreterFrame *, PyObject *, PyObject *, PyObject *);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(PyObject *)_PyEval_MatchClass(PyThreadState *tstate, PyObject *subject, PyObject *type, Py_ssize_t nargs, PyObject *kwargs);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(PyObject *)_PyEval_MatchKeys(PyThreadState *tstate, PyObject *map, PyObject *keys);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(void) _PyEval_MonitorRaise(PyThreadState *tstate, _PyInterpreterFrame *frame, _Py_CODEUNIT *instr);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(bool) _PyEval_NoToolsForUnwind(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(int) _PyEval_UnpackIterableStackRef(PyThreadState *tstate, PyObject *v, int argcnt, int argcntafter, _PyStackRef *sp);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(void) _PyEval_FrameClearAndPop(PyThreadState *tstate, _PyInterpreterFrame *frame);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(PyObject **) _PyObjectArray_FromStackRefArray(_PyStackRef *input, Py_ssize_t nargs, PyObject **scratch);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(void) _PyObjectArray_Free(PyObject **array, PyObject **scratch);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyEval_GetANext(PyObject *aiter);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(void) _PyEval_LoadGlobalStackRef(PyObject *globals, PyObject *builtins, PyObject *name, _PyStackRef *writeto);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyEval_GetAwaitable(PyObject *iterable, int oparg);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyEval_LoadName(PyThreadState *tstate, _PyInterpreterFrame *frame, PyObject *name);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(int) _Py_Check_ArgsIterable(PyThreadState *tstate, PyObject *func, PyObject *args);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(int) _PyEval_SpecialMethodCanSuggest(PyObject *self, int oparg);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(_PyStackRef) _PyFloat_FromDouble_ConsumeInputs(_PyStackRef left, _PyStackRef right, double value);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "(defined(Py_REMOTE_DEBUG) && defined(Py_SUPPORTS_REMOTE_DEBUG))",
             "extern int _PyRunRemoteDebugger(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_ceval.h",
             "",
             "PyAPI_FUNC(_PyStackRef) _Py_LoadAttr_StackRefSteal( PyThreadState *tstate, _PyStackRef owner, PyObject *name, _PyStackRef *self_or_null);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern PyStatus _PyCode_Init(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern void _PyCode_Fini(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern int _PyCode_Validate(struct _PyCodeConstructor *);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern PyCodeObject* _PyCode_New(struct _PyCodeConstructor *);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern PyObject* _PyCode_GetVarnames(PyCodeObject *);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern PyObject* _PyCode_GetCellvars(PyCodeObject *);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern PyObject* _PyCode_GetFreevars(PyCodeObject *);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern PyObject* _PyCode_GetCode(PyCodeObject *);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern int _PyCode_InitAddressRange(PyCodeObject* co, PyCodeAddressRange *bounds);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern void _PyLineTable_InitAddressRange( const char *linetable, Py_ssize_t length, int firstlineno, PyCodeAddressRange *range);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern int _PyLineTable_NextAddressRange(PyCodeAddressRange *range);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern int _PyLineTable_PreviousAddressRange(PyCodeAddressRange *range);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern int _PyCode_SafeAddr2Line(PyCodeObject *co, int addr);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern void _PyCode_Clear_Executors(PyCodeObject *code);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern void _Py_Specialize_LoadSuperAttr(_PyStackRef global_super, _PyStackRef cls, _Py_CODEUNIT *instr, int load_method);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern void _Py_Specialize_LoadAttr(_PyStackRef owner, _Py_CODEUNIT *instr, PyObject *name);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern void _Py_Specialize_StoreAttr(_PyStackRef owner, _Py_CODEUNIT *instr, PyObject *name);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern void _Py_Specialize_LoadGlobal(PyObject *globals, PyObject *builtins, _Py_CODEUNIT *instr, PyObject *name);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern void _Py_Specialize_StoreSubscr(_PyStackRef container, _PyStackRef sub, _Py_CODEUNIT *instr);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern void _Py_Specialize_Call(_PyStackRef callable, _Py_CODEUNIT *instr, int nargs);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern void _Py_Specialize_CallKw(_PyStackRef callable, _Py_CODEUNIT *instr, int nargs);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern void _Py_Specialize_BinaryOp(_PyStackRef lhs, _PyStackRef rhs, _Py_CODEUNIT *instr, int oparg, _PyStackRef *locals);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern void _Py_Specialize_CompareOp(_PyStackRef lhs, _PyStackRef rhs, _Py_CODEUNIT *instr, int oparg);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern void _Py_Specialize_UnpackSequence(_PyStackRef seq, _Py_CODEUNIT *instr, int oparg);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern void _Py_Specialize_ForIter(_PyStackRef iter, _Py_CODEUNIT *instr, int oparg);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern void _Py_Specialize_Send(_PyStackRef receiver, _Py_CODEUNIT *instr);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern void _Py_Specialize_ToBool(_PyStackRef value, _Py_CODEUNIT *instr);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern void _Py_Specialize_ContainsOp(_PyStackRef value, _Py_CODEUNIT *instr);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern void _Py_GatherStats_GetIter(_PyStackRef iterable);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern int _Py_Instrument(PyCodeObject *co, PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern _Py_CODEUNIT _Py_GetBaseCodeUnit(PyCodeObject *code, int offset);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern int _PyInstruction_GetLength(PyCodeObject *code, int offset);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "extern PyObject *_PyInstrumentation_BranchesIterator(PyCodeObject *code);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "PyAPI_DATA(const struct _PyCode8) _Py_InitCleanup;"
         ),
         (
             "Include/internal/pycore_code.h",
             "defined(Py_GIL_DISABLED)",
             "extern _Py_CODEUNIT *_PyCode_GetTLBC(PyCodeObject *co);"
         ),
         (
             "Include/internal/pycore_code.h",
             "defined(Py_GIL_DISABLED)",
             "extern int32_t _Py_ReserveTLBCIndex(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_code.h",
             "defined(Py_GIL_DISABLED)",
             "extern void _Py_ClearTLBCIndex(_PyThreadStateImpl *tstate);"
         ),
         (
             "Include/internal/pycore_code.h",
             "defined(Py_GIL_DISABLED)",
             "extern int _Py_ClearUnusedTLBC(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "PyAPI_FUNC(void) _PyCode_GetVarCounts( PyCodeObject *, _PyCode_var_counts_t *);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "PyAPI_FUNC(int) _PyCode_SetUnboundVarCounts( PyThreadState *, PyCodeObject *, _PyCode_var_counts_t *, PyObject *globalnames, PyObject *attrnames, PyObject *globalsns, PyObject *builtinsns);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "PyAPI_FUNC(int) _PyCode_CheckNoInternalState(PyCodeObject *, const char **);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "PyAPI_FUNC(int) _PyCode_CheckNoExternalState( PyCodeObject *, _PyCode_var_counts_t *, const char **);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "PyAPI_FUNC(int) _PyCode_VerifyStateless( PyThreadState *, PyCodeObject *, PyObject *globalnames, PyObject *globalsns, PyObject *builtinsns);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "PyAPI_FUNC(int) _PyCode_CheckPureFunction(PyCodeObject *, const char **);"
         ),
         (
             "Include/internal/pycore_code.h",
             "",
             "PyAPI_FUNC(int) _PyCode_ReturnsOnlyNone(PyCodeObject *);"
         ),
         (
             "Include/internal/pycore_codecs.h",
             "",
             "extern PyStatus _PyCodec_InitRegistry(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_codecs.h",
             "",
             "extern void _PyCodec_Fini(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_codecs.h",
             "",
             "extern PyObject* _PyCodec_Lookup(const char *encoding);"
         ),
         (
             "Include/internal/pycore_codecs.h",
             "",
             "extern int _PyCodec_UnregisterError(const char *name);"
         ),
         (
             "Include/internal/pycore_codecs.h",
             "",
             "extern PyObject* _PyCodec_LookupTextEncoding( const char *encoding, const char *alternate_command);"
         ),
         (
             "Include/internal/pycore_codecs.h",
             "",
             "extern PyObject* _PyCodec_EncodeText( PyObject *object, const char *encoding, const char *errors);"
         ),
         (
             "Include/internal/pycore_codecs.h",
             "",
             "extern PyObject* _PyCodec_DecodeText( PyObject *object, const char *encoding, const char *errors);"
         ),
         (
             "Include/internal/pycore_codecs.h",
             "",
             "extern PyObject* _PyCodecInfo_GetIncrementalDecoder( PyObject *codec_info, const char *errors);"
         ),
         (
             "Include/internal/pycore_codecs.h",
             "",
             "extern PyObject* _PyCodecInfo_GetIncrementalEncoder( PyObject *codec_info, const char *errors);"
         ),
         (
             "Include/internal/pycore_compile.h",
             "",
             "PyAPI_FUNC(PyCodeObject*) _PyAST_Compile( struct _mod *mod, PyObject *filename, PyCompilerFlags *flags, int optimize, struct _arena *arena);"
         ),
         (
             "Include/internal/pycore_compile.h",
             "",
             "extern int _PyCompile_AstPreprocess( struct _mod *mod, PyObject *filename, PyCompilerFlags *flags, int optimize, struct _arena *arena, int syntax_check_only);"
         ),
         (
             "Include/internal/pycore_compile.h",
             "",
             "extern int _PyAST_Preprocess( struct _mod *, struct _arena *arena, PyObject *filename, int optimize, int ff_features, int syntax_check_only, int enable_warnings);"
         ),
         (
             "Include/internal/pycore_compile.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyCompile_GetUnaryIntrinsicName(int index);"
         ),
         (
             "Include/internal/pycore_compile.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyCompile_GetBinaryIntrinsicName(int index);"
         ),
         (
             "Include/internal/pycore_compile.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyCompile_CleanDoc(PyObject *doc);"
         ),
         (
             "Include/internal/pycore_compile.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyCompile_CodeGen( PyObject *ast, PyObject *filename, PyCompilerFlags *flags, int optimize, int compile_mode);"
         ),
         (
             "Include/internal/pycore_compile.h",
             "",
             "PyAPI_FUNC(PyCodeObject*) _PyCompile_Assemble(_PyCompile_CodeUnitMetadata *umd, PyObject *filename, PyObject *instructions);"
         ),
         (
             "Include/internal/pycore_complexobject.h",
             "",
             "extern int _PyComplex_FormatAdvancedWriter( _PyUnicodeWriter *writer, PyObject *obj, PyObject *format_spec, Py_ssize_t start, Py_ssize_t end);"
         ),
         (
             "Include/internal/pycore_complexobject.h",
             "",
             "PyAPI_FUNC(Py_complex) _Py_cr_sum(Py_complex, double);"
         ),
         (
             "Include/internal/pycore_complexobject.h",
             "",
             "PyAPI_FUNC(Py_complex) _Py_cr_diff(Py_complex, double);"
         ),
         (
             "Include/internal/pycore_complexobject.h",
             "",
             "PyAPI_FUNC(Py_complex) _Py_rc_diff(double, Py_complex);"
         ),
         (
             "Include/internal/pycore_complexobject.h",
             "",
             "PyAPI_FUNC(Py_complex) _Py_cr_prod(Py_complex, double);"
         ),
         (
             "Include/internal/pycore_complexobject.h",
             "",
             "PyAPI_FUNC(Py_complex) _Py_cr_quot(Py_complex, double);"
         ),
         (
             "Include/internal/pycore_complexobject.h",
             "",
             "PyAPI_FUNC(Py_complex) _Py_rc_quot(double, Py_complex);"
         ),
         (
             "Include/internal/pycore_context.h",
             "",
             "extern PyTypeObject _PyContextTokenMissing_Type;"
         ),
         (
             "Include/internal/pycore_context.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyContext_NewHamtForTests(void);"
         ),
         (
             "Include/internal/pycore_critical_section.h",
             "",
             "PyAPI_FUNC(void) _PyCriticalSection_Resume(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_critical_section.h",
             "",
             "PyAPI_FUNC(void) _PyCriticalSection_BeginSlow(PyCriticalSection *c, PyMutex *m);"
         ),
         (
             "Include/internal/pycore_critical_section.h",
             "",
             "PyAPI_FUNC(void) _PyCriticalSection2_BeginSlow(PyCriticalSection2 *c, PyMutex *m1, PyMutex *m2, int is_m1_locked);"
         ),
         (
             "Include/internal/pycore_critical_section.h",
             "",
             "PyAPI_FUNC(void) _PyCriticalSection_SuspendAll(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_DATA(PyObject *) PyExc_InterpreterError;"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_DATA(PyObject *) PyExc_InterpreterNotFoundError;"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "extern int _Py_CallInInterpreter( PyInterpreterState *interp, _Py_simple_func func, void *arg);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "extern int _Py_CallInInterpreterAndRawFree( PyInterpreterState *interp, _Py_simple_func func, void *arg);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(_PyXIData_t *) _PyXIData_New(void);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(void) _PyXIData_Free(_PyXIData_t *data);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(void) _PyXIData_Init( _PyXIData_t *data, PyInterpreterState *interp, void *shared, PyObject *obj, xid_newobjfunc new_object);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(int) _PyXIData_InitWithSize( _PyXIData_t *, PyInterpreterState *interp, const size_t, PyObject *, xid_newobjfunc);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(void) _PyXIData_Clear(PyInterpreterState *, _PyXIData_t *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyXIData_GetNotShareableErrorType(PyThreadState *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(void) _PyXIData_SetNotShareableError(PyThreadState *, const char *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(void) _PyXIData_FormatNotShareableError( PyThreadState *, const char *, ...);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(_PyXIData_getdata_t) _PyXIData_Lookup( PyThreadState *, PyObject *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(int) _PyObject_CheckXIData( PyThreadState *, PyObject *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(int) _PyObject_GetXIDataNoFallback( PyThreadState *, PyObject *, _PyXIData_t *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(int) _PyObject_GetXIData( PyThreadState *, PyObject *, xidata_fallback_t, _PyXIData_t *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(int) _PyBytes_GetData(PyObject *, _PyBytes_data_t *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyBytes_FromData(_PyBytes_data_t *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyBytes_FromXIData(_PyXIData_t *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(int) _PyBytes_GetXIData( PyThreadState *, PyObject *, _PyXIData_t *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(_PyBytes_data_t *) _PyBytes_GetXIDataWrapped( PyThreadState *, PyObject *, size_t, xid_newobjfunc, _PyXIData_t *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_DATA(PyObject *) _PyPickle_LoadFromXIData(_PyXIData_t *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(int) _PyPickle_GetXIData( PyThreadState *, PyObject *, _PyXIData_t *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyMarshal_ReadObjectFromXIData(_PyXIData_t *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(int) _PyMarshal_GetXIData( PyThreadState *, PyObject *, _PyXIData_t *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyCode_FromXIData(_PyXIData_t *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(int) _PyCode_GetXIData( PyThreadState *, PyObject *, _PyXIData_t *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(int) _PyCode_GetScriptXIData( PyThreadState *, PyObject *, _PyXIData_t *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(int) _PyCode_GetPureScriptXIData( PyThreadState *, PyObject *, _PyXIData_t *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyFunction_FromXIData(_PyXIData_t *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(int) _PyFunction_GetXIData( PyThreadState *, PyObject *, _PyXIData_t *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyXIData_NewObject(_PyXIData_t *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(int) _PyXIData_Release(_PyXIData_t *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(int) _PyXIData_ReleaseAndRawFree(_PyXIData_t *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "!defined(Py_BUILD_CORE_MODULE)",
             "extern PyStatus _PyXI_Init(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "!defined(Py_BUILD_CORE_MODULE)",
             "extern void _PyXI_Fini(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "!defined(Py_BUILD_CORE_MODULE)",
             "extern PyStatus _PyXI_InitTypes(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "!defined(Py_BUILD_CORE_MODULE)",
             "extern void _PyXI_FiniTypes(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(_PyXI_excinfo *) _PyXI_NewExcInfo(PyObject *exc);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(void) _PyXI_FreeExcInfo(_PyXI_excinfo *info);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyXI_FormatExcInfo(_PyXI_excinfo *info);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyXI_ExcInfoAsObject(_PyXI_excinfo *info);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(_PyXI_failure *) _PyXI_NewFailure(void);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(void) _PyXI_FreeFailure(_PyXI_failure *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(_PyXI_errcode) _PyXI_GetFailureCode(_PyXI_failure *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(int) _PyXI_InitFailure(_PyXI_failure *, _PyXI_errcode, PyObject *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(void) _PyXI_InitFailureUTF8( _PyXI_failure *, _PyXI_errcode, const char *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(int) _PyXI_UnwrapNotShareableError( PyThreadState *, _PyXI_failure *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(_PyXI_session *) _PyXI_NewSession(void);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(void) _PyXI_FreeSession(_PyXI_session *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(void) _PyXI_ClearResult(_PyXI_session_result *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(int) _PyXI_Enter( _PyXI_session *session, PyInterpreterState *interp, PyObject *nsupdates, _PyXI_session_result *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(int) _PyXI_Exit( _PyXI_session *, _PyXI_failure *, _PyXI_session_result *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyXI_GetMainNamespace( _PyXI_session *, _PyXI_failure *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(int) _PyXI_Preserve( _PyXI_session *, const char *, PyObject *, _PyXI_failure *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyXI_GetPreserved( _PyXI_session_result *, const char *);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(PyInterpreterState *) _PyXI_NewInterpreter( PyInterpreterConfig *config, long *maybe_whence, PyThreadState **p_tstate, PyThreadState **p_save_tstate);"
         ),
         (
             "Include/internal/pycore_crossinterp.h",
             "",
             "PyAPI_FUNC(void) _PyXI_EndInterpreter( PyInterpreterState *interp, PyThreadState *tstate, PyThreadState **p_save_tstate);"
         ),
         (
             "Include/internal/pycore_crossinterp_data_registry.h",
             "",
             "PyAPI_FUNC(int) _PyXIData_RegisterClass( PyThreadState *, PyTypeObject *, _PyXIData_getdata_t);"
         ),
         (
             "Include/internal/pycore_crossinterp_data_registry.h",
             "",
             "PyAPI_FUNC(int) _PyXIData_UnregisterClass( PyThreadState *, PyTypeObject *);"
         ),
         (
             "Include/internal/pycore_descrobject.h",
             "",
             "extern PyTypeObject _PyMethodWrapper_Type;"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern PyObject* _PyDict_GetItemWithError(PyObject *dp, PyObject *key);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "PyAPI_FUNC(int) _PyDict_DelItemIf(PyObject *mp, PyObject *key, int (*predicate)(PyObject *value, void *arg), void *arg);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "PyAPI_FUNC(int) _PyDict_SetItem_KnownHash(PyObject *mp, PyObject *key, PyObject *item, Py_hash_t hash);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "PyAPI_FUNC(int) _PyDict_DelItem_KnownHash(PyObject *mp, PyObject *key, Py_hash_t hash);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern int _PyDict_DelItem_KnownHash_LockHeld(PyObject *mp, PyObject *key, Py_hash_t hash);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern int _PyDict_Contains_KnownHash(PyObject *, PyObject *, Py_hash_t);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern PyObject* _PyDict_GetItemIdWithError(PyObject *dp, _Py_Identifier *key);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern int _PyDict_ContainsId(PyObject *, _Py_Identifier *);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern int _PyDict_SetItemId(PyObject *dp, _Py_Identifier *key, PyObject *item);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern int _PyDict_DelItemId(PyObject *mp, _Py_Identifier *key);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern int _PyDict_Next( PyObject *mp, Py_ssize_t *pos, PyObject **key, PyObject **value, Py_hash_t *hash);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern int _PyDict_HasOnlyStringKeys(PyObject *mp);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) _PyDict_SizeOf(PyDictObject *);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern Py_ssize_t _PyDict_SizeOf_LockHeld(PyDictObject *);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "PyAPI_FUNC(int) _PyDict_MergeEx(PyObject *mp, PyObject *other, int override);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern void _PyDict_DebugMallocStats(FILE *out);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern PyObject* _PyDictView_New(PyObject *, PyTypeObject *);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern PyObject* _PyDictView_Intersect(PyObject* self, PyObject *other);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern PyDictKeysObject *_PyDict_NewKeysForClass(PyHeapTypeObject *);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern PyObject *_PyDict_FromKeys(PyObject *, PyObject *, PyObject *);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern uint32_t _PyDictKeys_GetVersionForCurrentState( PyInterpreterState *interp, PyDictKeysObject *dictkeys);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern uint32_t _PyDict_GetKeysVersionForCurrentState( PyInterpreterState *interp, PyDictObject *dict);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern size_t _PyDict_KeysSize(PyDictKeysObject *keys);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern void _PyDictKeys_DecRef(PyDictKeysObject *keys);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern Py_ssize_t _Py_dict_lookup(PyDictObject *mp, PyObject *key, Py_hash_t hash, PyObject **value_addr);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern Py_ssize_t _Py_dict_lookup_threadsafe(PyDictObject *mp, PyObject *key, Py_hash_t hash, PyObject **value_addr);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern Py_ssize_t _Py_dict_lookup_threadsafe_stackref(PyDictObject *mp, PyObject *key, Py_hash_t hash, _PyStackRef *value_addr);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern int _PyDict_GetMethodStackRef(PyDictObject *dict, PyObject *name, _PyStackRef *method);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern Py_ssize_t _PyDict_LookupIndex(PyDictObject *, PyObject *);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern Py_ssize_t _PyDictKeys_StringLookup(PyDictKeysObject* dictkeys, PyObject *key);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern Py_ssize_t _PyDictKeys_StringLookupAndVersion(PyDictKeysObject* dictkeys, PyObject *key, uint32_t *version);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern Py_ssize_t _PyDictKeys_StringLookupSplit(PyDictKeysObject* dictkeys, PyObject *key);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "PyAPI_FUNC(PyObject *)_PyDict_LoadGlobal(PyDictObject *, PyDictObject *, PyObject *);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "PyAPI_FUNC(void) _PyDict_LoadGlobalStackRef(PyDictObject *, PyDictObject *, PyObject *, _PyStackRef *);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern PyObject *_PyDict_LoadBuiltinsFromGlobals(PyObject *globals);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "PyAPI_FUNC(int) _PyDict_SetItem_Take2(PyDictObject *op, PyObject *key, PyObject *value);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern int _PyDict_SetItem_LockHeld(PyDictObject *dict, PyObject *name, PyObject *value);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "PyAPI_FUNC(int) _PyDict_SetItem_KnownHash_LockHeld(PyDictObject *mp, PyObject *key, PyObject *value, Py_hash_t hash);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "PyAPI_FUNC(int) _PyDict_GetItemRef_KnownHash_LockHeld(PyDictObject *op, PyObject *key, Py_hash_t hash, PyObject **result);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern int _PyDict_GetItemRef_KnownHash(PyDictObject *op, PyObject *key, Py_hash_t hash, PyObject **result);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern int _PyDict_GetItemRef_Unicode_LockHeld(PyDictObject *op, PyObject *key, PyObject **result);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern int _PyObjectDict_SetItem(PyTypeObject *tp, PyObject *obj, PyObject **dictptr, PyObject *name, PyObject *value);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern int _PyDict_Pop_KnownHash( PyDictObject *dict, PyObject *key, Py_hash_t hash, PyObject **result);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern void _PyDict_Clear_LockHeld(PyObject *op);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "defined(Py_GIL_DISABLED)",
             "PyAPI_FUNC(void) _PyDict_EnsureSharedOnRead(PyDictObject *mp);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "PyAPI_FUNC(void) _PyDict_SendEvent(int watcher_bits, PyDict_WatchEvent event, PyDictObject *mp, PyObject *key, PyObject *value);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern PyDictObject *_PyObject_MaterializeManagedDict(PyObject *obj);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "PyAPI_FUNC(PyObject *)_PyDict_FromItems( PyObject *const *keys, Py_ssize_t keys_offset, PyObject *const *values, Py_ssize_t values_offset, Py_ssize_t length);"
         ),
         (
             "Include/internal/pycore_dict.h",
             "",
             "extern void _PyDict_EnablePerThreadRefcounting(PyObject *op);"
         ),
         (
             "Include/internal/pycore_dtoa.h",
             "",
             "extern double _Py_dg_strtod(const char *str, char **ptr);"
         ),
         (
             "Include/internal/pycore_dtoa.h",
             "",
             "extern char* _Py_dg_dtoa(double d, int mode, int ndigits, int *decpt, int *sign, char **rve);"
         ),
         (
             "Include/internal/pycore_dtoa.h",
             "",
             "extern void _Py_dg_freedtoa(char *s);"
         ),
         (
             "Include/internal/pycore_dtoa.h",
             "",
             "extern PyStatus _PyDtoa_Init(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_dtoa.h",
             "",
             "extern void _PyDtoa_Fini(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_emscripten_signal.h",
             "defined(__EMSCRIPTEN__)",
             "extern int Py_EMSCRIPTEN_SIGNAL_HANDLING;"
         ),
         (
             "Include/internal/pycore_emscripten_signal.h",
             "defined(__EMSCRIPTEN__)",
             "extern int _Py_emscripten_signal_clock;"
         ),
         (
             "Include/internal/pycore_exceptions.h",
             "",
             "extern PyStatus _PyExc_InitState(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_exceptions.h",
             "",
             "extern PyStatus _PyExc_InitGlobalObjects(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_exceptions.h",
             "",
             "extern int _PyExc_InitTypes(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_exceptions.h",
             "",
             "extern void _PyExc_Fini(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_exceptions.h",
             "",
             "extern void _PyExc_ClearExceptionGroupType(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "PyAPI_FUNC(_Py_error_handler) _Py_GetErrorHandler(const char *errors);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "PyAPI_FUNC(int) _Py_DecodeLocaleEx( const char *arg, wchar_t **wstr, size_t *wlen, const char **reason, int current_locale, _Py_error_handler errors);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "PyAPI_FUNC(int) _Py_EncodeLocaleEx( const wchar_t *text, char **str, size_t *error_pos, const char **reason, int current_locale, _Py_error_handler errors);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "extern char* _Py_EncodeLocaleRaw( const wchar_t *text, size_t *error_pos);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "extern PyObject* _Py_device_encoding(int);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "PyAPI_FUNC(int) _Py_fstat( int fd, struct _Py_stat_struct *status);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "PyAPI_FUNC(int) _Py_fstat_noraise( int fd, struct _Py_stat_struct *status);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "PyAPI_FUNC(int) _Py_stat( PyObject *path, struct stat *status);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "PyAPI_FUNC(int) _Py_open( const char *pathname, int flags);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "PyAPI_FUNC(int) _Py_open_noraise( const char *pathname, int flags);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "extern FILE* _Py_wfopen( const wchar_t *path, const wchar_t *mode);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "extern Py_ssize_t _Py_read( int fd, void *buf, size_t count);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) _Py_write( int fd, const void *buf, size_t count);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) _Py_write_noraise( int fd, const void *buf, size_t count);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "defined(HAVE_READLINK)",
             "extern int _Py_wreadlink( const wchar_t *path, wchar_t *buf, size_t buflen);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "defined(HAVE_REALPATH)",
             "extern wchar_t* _Py_wrealpath( const wchar_t *path, wchar_t *resolved_path, size_t resolved_path_len);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "extern wchar_t* _Py_wgetcwd( wchar_t *buf, size_t buflen);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "extern int _Py_get_inheritable(int fd);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "PyAPI_FUNC(int) _Py_set_inheritable(int fd, int inheritable, int *atomic_flag_works);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "PyAPI_FUNC(int) _Py_set_inheritable_async_safe(int fd, int inheritable, int *atomic_flag_works);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "PyAPI_FUNC(int) _Py_dup(int fd);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "extern int _Py_get_blocking(int fd);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "extern int _Py_set_blocking(int fd, int blocking);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "defined(MS_WINDOWS)",
             "extern void* _Py_get_osfhandle_noraise(int fd);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "defined(MS_WINDOWS)",
             "PyAPI_FUNC(void*) _Py_get_osfhandle(int fd);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "defined(MS_WINDOWS)",
             "extern int _Py_open_osfhandle_noraise(void *handle, int flags);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "defined(MS_WINDOWS)",
             "extern int _Py_open_osfhandle(void *handle, int flags);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "extern int _Py_HasFileSystemDefaultEncodeErrors;"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "extern int _Py_DecodeUTF8Ex( const char *arg, Py_ssize_t arglen, wchar_t **wstr, size_t *wlen, const char **reason, _Py_error_handler errors);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "extern int _Py_EncodeUTF8Ex( const wchar_t *text, char **str, size_t *error_pos, const char **reason, int raw_malloc, _Py_error_handler errors);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "extern wchar_t* _Py_DecodeUTF8_surrogateescape( const char *arg, Py_ssize_t arglen, size_t *wlen);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "extern int _Py_GetForceASCII(void);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "extern void _Py_ResetForceASCII(void);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "extern int _Py_GetLocaleconvNumeric( struct lconv *lc, PyObject **decimal_point, PyObject **thousands_sep);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "PyAPI_FUNC(void) _Py_closerange(int first, int last);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "extern wchar_t* _Py_GetLocaleEncoding(void);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "extern PyObject* _Py_GetLocaleEncodingObject(void);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "defined(HAVE_NON_UNICODE_WCHAR_T_REPRESENTATION)",
             "extern int _Py_LocaleUsesNonUnicodeWchar(void);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "defined(HAVE_NON_UNICODE_WCHAR_T_REPRESENTATION)",
             "extern wchar_t* _Py_DecodeNonUnicodeWchar( const wchar_t* native, Py_ssize_t size);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "defined(HAVE_NON_UNICODE_WCHAR_T_REPRESENTATION)",
             "extern int _Py_EncodeNonUnicodeWchar_InPlace( wchar_t* unicode, Py_ssize_t size);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "extern int _Py_isabs(const wchar_t *path);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "extern int _Py_abspath(const wchar_t *path, wchar_t **abspath_p);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "defined(MS_WINDOWS)",
             "extern int _PyOS_getfullpathname(const wchar_t *path, wchar_t **abspath_p);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "extern wchar_t* _Py_join_relfile(const wchar_t *dirname, const wchar_t *relfile);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "extern int _Py_add_relfile(wchar_t *dirname, const wchar_t *relfile, size_t bufsize);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "extern size_t _Py_find_basename(const wchar_t *filename);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "PyAPI_FUNC(wchar_t*) _Py_normpath(wchar_t *path, Py_ssize_t size);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "extern wchar_t *_Py_normpath_and_size(wchar_t *path, Py_ssize_t size, Py_ssize_t *length);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "(defined(MS_WINDOWS_GAMES) && !defined(MS_WINDOWS_DESKTOP))",
             "extern HRESULT PathCchSkipRoot(const wchar_t *pszPath, const wchar_t **ppszRootEnd);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "extern void _Py_skiproot(const wchar_t *path, Py_ssize_t size, Py_ssize_t *drvsize, Py_ssize_t *rootsize);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "(defined _MSC_VER && _MSC_VER >= 1900)",
             "extern _invalid_parameter_handler _Py_silent_invalid_parameter_handler;"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "PyAPI_FUNC(int) _PyLong_FileDescriptor_Converter(PyObject *, void *);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "PyAPI_FUNC(char*) _Py_UniversalNewlineFgetsWithSize(char *, int, FILE*, PyObject *, size_t*);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "extern int _PyFile_Flush(PyObject *);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "!defined(MS_WINDOWS)",
             "extern int _Py_GetTicksPerSecond(long *ticks_per_second);"
         ),
         (
             "Include/internal/pycore_fileutils.h",
             "",
             "PyAPI_FUNC(int) _Py_IsValidFD(int fd);"
         ),
         (
             "Include/internal/pycore_floatobject.h",
             "",
             "extern void _PyFloat_InitState(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_floatobject.h",
             "",
             "extern PyStatus _PyFloat_InitTypes(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_floatobject.h",
             "",
             "extern void _PyFloat_FiniType(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_floatobject.h",
             "",
             "PyAPI_FUNC(void) _PyFloat_ExactDealloc(PyObject *op);"
         ),
         (
             "Include/internal/pycore_floatobject.h",
             "",
             "extern void _PyFloat_DebugMallocStats(FILE* out);"
         ),
         (
             "Include/internal/pycore_floatobject.h",
             "",
             "extern int _PyFloat_FormatAdvancedWriter( _PyUnicodeWriter *writer, PyObject *obj, PyObject *format_spec, Py_ssize_t start, Py_ssize_t end);"
         ),
         (
             "Include/internal/pycore_floatobject.h",
             "",
             "extern PyObject* _Py_string_to_number_with_underscores( const char *str, Py_ssize_t len, const char *what, PyObject *obj, void *arg, PyObject *(*innerfunc)(const char *, Py_ssize_t, void *));"
         ),
         (
             "Include/internal/pycore_floatobject.h",
             "",
             "extern double _Py_parse_inf_or_nan(const char *p, char **endptr);"
         ),
         (
             "Include/internal/pycore_floatobject.h",
             "",
             "extern int _Py_convert_int_to_double(PyObject **v, double *dbl);"
         ),
         (
             "Include/internal/pycore_flowgraph.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyCompile_OptimizeCfg( PyObject *instructions, PyObject *consts, int nlocals);"
         ),
         (
             "Include/internal/pycore_frame.h",
             "",
             "extern PyFrameObject* _PyFrame_New_NoTrack(PyCodeObject *code);"
         ),
         (
             "Include/internal/pycore_freelist.h",
             "",
             "extern void _PyObject_ClearFreeLists(struct _Py_freelists *freelists, int is_finalization);"
         ),
         (
             "Include/internal/pycore_function.h",
             "",
             "extern PyObject* _PyFunction_Vectorcall( PyObject *func, PyObject *const *stack, size_t nargsf, PyObject *kwnames);"
         ),
         (
             "Include/internal/pycore_function.h",
             "",
             "extern PyFunctionObject* _PyFunction_FromConstructor(PyFrameConstructor *constr);"
         ),
         (
             "Include/internal/pycore_function.h",
             "",
             "extern uint32_t _PyFunction_GetVersionForCurrentState(PyFunctionObject *func);"
         ),
         (
             "Include/internal/pycore_function.h",
             "",
             "PyAPI_FUNC(void) _PyFunction_SetVersion(PyFunctionObject *func, uint32_t version);"
         ),
         (
             "Include/internal/pycore_function.h",
             "",
             "extern PyObject *_Py_set_function_type_params( PyThreadState* unused, PyObject *func, PyObject *type_params);"
         ),
         (
             "Include/internal/pycore_function.h",
             "",
             "PyAPI_FUNC(int) _PyFunction_VerifyStateless(PyThreadState *, PyObject *);"
         ),
         (
             "Include/internal/pycore_function.h",
             "",
             "extern PyObject *_PyClassMethod_GetFunc(PyObject *cm);"
         ),
         (
             "Include/internal/pycore_function.h",
             "",
             "extern PyObject *_PyStaticMethod_GetFunc(PyObject *sm);"
         ),
         (
             "Include/internal/pycore_gc.h",
             "",
             "extern void _Py_ScheduleGC(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_gc.h",
             "",
             "extern void _PyGC_InitState(struct _gc_runtime_state *);"
         ),
         (
             "Include/internal/pycore_gc.h",
             "",
             "extern Py_ssize_t _PyGC_Collect(PyThreadState *tstate, int generation, _PyGC_Reason reason);"
         ),
         (
             "Include/internal/pycore_gc.h",
             "",
             "extern void _PyGC_CollectNoFail(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_gc.h",
             "",
             "extern void _PyGC_Freeze(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_gc.h",
             "",
             "extern void _PyGC_Unfreeze(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_gc.h",
             "",
             "extern Py_ssize_t _PyGC_GetFreezeCount(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_gc.h",
             "",
             "extern PyObject *_PyGC_GetObjects(PyInterpreterState *interp, int generation);"
         ),
         (
             "Include/internal/pycore_gc.h",
             "",
             "extern PyObject *_PyGC_GetReferrers(PyInterpreterState *interp, PyObject *objs);"
         ),
         (
             "Include/internal/pycore_gc.h",
             "",
             "extern void _PyGC_ClearAllFreeLists(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_gc.h",
             "",
             "extern void _Py_RunGC(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_gc.h",
             "",
             "extern int _PyGC_VisitFrameStack(_PyInterpreterFrame *frame, visitproc visit, void *arg);"
         ),
         (
             "Include/internal/pycore_gc.h",
             "",
             "extern int _PyGC_VisitStackRef(union _PyStackRef *ref, visitproc visit, void *arg);"
         ),
         (
             "Include/internal/pycore_gc.h",
             "defined(Py_GIL_DISABLED)",
             "extern void _PyGC_VisitObjectsWorldStopped(PyInterpreterState *interp, gcvisitobjects_t callback, void *arg);"
         ),
         (
             "Include/internal/pycore_genobject.h",
             "",
             "PyAPI_FUNC(PyObject *)_PyGen_yf(PyGenObject *);"
         ),
         (
             "Include/internal/pycore_genobject.h",
             "",
             "extern void _PyGen_Finalize(PyObject *self);"
         ),
         (
             "Include/internal/pycore_genobject.h",
             "",
             "PyAPI_FUNC(int) _PyGen_SetStopIterationValue(PyObject *);"
         ),
         (
             "Include/internal/pycore_genobject.h",
             "",
             "PyAPI_FUNC(int) _PyGen_FetchStopIterationValue(PyObject **);"
         ),
         (
             "Include/internal/pycore_genobject.h",
             "",
             "PyAPI_FUNC(PyObject *)_PyCoro_GetAwaitableIter(PyObject *o);"
         ),
         (
             "Include/internal/pycore_genobject.h",
             "",
             "extern PyObject *_PyAsyncGenValueWrapperNew(PyThreadState *state, PyObject *);"
         ),
         (
             "Include/internal/pycore_genobject.h",
             "",
             "extern PyTypeObject _PyCoroWrapper_Type;"
         ),
         (
             "Include/internal/pycore_genobject.h",
             "",
             "extern PyTypeObject _PyAsyncGenWrappedValue_Type;"
         ),
         (
             "Include/internal/pycore_genobject.h",
             "",
             "extern PyTypeObject _PyAsyncGenAThrow_Type;"
         ),
         ("Include/internal/pycore_getopt.h", "", "extern int _PyOS_opterr;"),
         ("Include/internal/pycore_getopt.h", "", "extern Py_ssize_t _PyOS_optind;"),
         (
             "Include/internal/pycore_getopt.h",
             "",
             "extern const wchar_t *_PyOS_optarg;"
         ),
         (
             "Include/internal/pycore_getopt.h",
             "",
             "extern void _PyOS_ResetGetOpt(void);"
         ),
         (
             "Include/internal/pycore_getopt.h",
             "",
             "extern int _PyOS_GetOpt(Py_ssize_t argc, wchar_t * const *argv, int *longindex);"
         ),
         ("Include/internal/pycore_hamt.h", "", "extern PyTypeObject _PyHamt_Type;"),
         (
             "Include/internal/pycore_hamt.h",
             "",
             "extern PyTypeObject _PyHamt_ArrayNode_Type;"
         ),
         (
             "Include/internal/pycore_hamt.h",
             "",
             "extern PyTypeObject _PyHamt_BitmapNode_Type;"
         ),
         (
             "Include/internal/pycore_hamt.h",
             "",
             "extern PyTypeObject _PyHamt_CollisionNode_Type;"
         ),
         (
             "Include/internal/pycore_hamt.h",
             "",
             "extern PyTypeObject _PyHamtKeys_Type;"
         ),
         (
             "Include/internal/pycore_hamt.h",
             "",
             "extern PyTypeObject _PyHamtValues_Type;"
         ),
         (
             "Include/internal/pycore_hamt.h",
             "",
             "extern PyTypeObject _PyHamtItems_Type;"
         ),
         (
             "Include/internal/pycore_hashtable.h",
             "",
             "PyAPI_FUNC(_Py_hashtable_t *) _Py_hashtable_new( _Py_hashtable_hash_func hash_func, _Py_hashtable_compare_func compare_func);"
         ),
         (
             "Include/internal/pycore_hashtable.h",
             "",
             "PyAPI_FUNC(Py_uhash_t) _Py_hashtable_hash_ptr(const void *key);"
         ),
         (
             "Include/internal/pycore_hashtable.h",
             "",
             "PyAPI_FUNC(int) _Py_hashtable_compare_direct( const void *key1, const void *key2);"
         ),
         (
             "Include/internal/pycore_hashtable.h",
             "",
             "PyAPI_FUNC(_Py_hashtable_t *) _Py_hashtable_new_full( _Py_hashtable_hash_func hash_func, _Py_hashtable_compare_func compare_func, _Py_hashtable_destroy_func key_destroy_func, _Py_hashtable_destroy_func value_destroy_func, _Py_hashtable_allocator_t *allocator);"
         ),
         (
             "Include/internal/pycore_hashtable.h",
             "",
             "PyAPI_FUNC(void) _Py_hashtable_destroy(_Py_hashtable_t *ht);"
         ),
         (
             "Include/internal/pycore_hashtable.h",
             "",
             "PyAPI_FUNC(void) _Py_hashtable_clear(_Py_hashtable_t *ht);"
         ),
         (
             "Include/internal/pycore_hashtable.h",
             "",
             "PyAPI_FUNC(int) _Py_hashtable_foreach( _Py_hashtable_t *ht, _Py_hashtable_foreach_func func, void *user_data);"
         ),
         (
             "Include/internal/pycore_hashtable.h",
             "",
             "PyAPI_FUNC(size_t) _Py_hashtable_size(const _Py_hashtable_t *ht);"
         ),
         (
             "Include/internal/pycore_hashtable.h",
             "",
             "PyAPI_FUNC(size_t) _Py_hashtable_len(const _Py_hashtable_t *ht);"
         ),
         (
             "Include/internal/pycore_hashtable.h",
             "",
             "PyAPI_FUNC(int) _Py_hashtable_set( _Py_hashtable_t *ht, const void *key, void *value);"
         ),
         (
             "Include/internal/pycore_hashtable.h",
             "",
             "PyAPI_FUNC(void*) _Py_hashtable_get(_Py_hashtable_t *ht, const void *key);"
         ),
         (
             "Include/internal/pycore_hashtable.h",
             "",
             "PyAPI_FUNC(void*) _Py_hashtable_steal( _Py_hashtable_t *ht, const void *key);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern int _PyImport_IsInitialized(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) _PyImport_SetModule(PyObject *name, PyObject *module);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern int _PyImport_SetModuleString(const char *name, PyObject* module);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern void _PyImport_AcquireLock(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern void _PyImport_ReleaseLock(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern void _PyImport_ReInitLock(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern int _PyImport_FixupBuiltin( PyThreadState *tstate, PyObject *mod, const char *name, PyObject *modules );"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern void _PyImport_ClearCore(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern Py_ssize_t _PyImport_GetNextModuleIndex(void);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern const char * _PyImport_ResolveNameWithPackageContext(const char *name);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern const char * _PyImport_SwapPackageContext(const char *newcontext);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern int _PyImport_GetDLOpenFlags(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern void _PyImport_SetDLOpenFlags(PyInterpreterState *interp, int new_val);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern PyObject * _PyImport_InitModules(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern PyObject * _PyImport_GetModules(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern PyObject * _PyImport_GetModulesRef(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern void _PyImport_ClearModules(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern void _PyImport_ClearModulesByIndex(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern int _PyImport_InitDefaultImportFunc(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern int _PyImport_IsDefaultImportFunc( PyInterpreterState *interp, PyObject *func);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern PyObject * _PyImport_GetImportlibLoader( PyInterpreterState *interp, const char *loader_name);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern PyObject * _PyImport_GetImportlibExternalLoader( PyInterpreterState *interp, const char *loader_name);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern PyObject * _PyImport_BlessMyLoader( PyInterpreterState *interp, PyObject *module_globals);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern PyObject * _PyImport_ImportlibModuleRepr( PyInterpreterState *interp, PyObject *module);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern PyStatus _PyImport_Init(void);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern void _PyImport_Fini(void);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern void _PyImport_Fini2(void);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern PyStatus _PyImport_InitCore( PyThreadState *tstate, PyObject *sysmod, int importlib);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern PyStatus _PyImport_InitExternal(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern void _PyImport_FiniCore(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern void _PyImport_FiniExternal(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern PyObject* _PyImport_GetBuiltinModuleNames(void);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_DATA(const struct _frozen*) _PyImport_FrozenBootstrap;"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_DATA(const struct _frozen*) _PyImport_FrozenStdlib;"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_DATA(const struct _frozen*) _PyImport_FrozenTest;"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "extern int _PyImport_CheckSubinterpIncompatibleExtensionAllowed( const char *name);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) _PyImport_ClearExtension(PyObject *name, PyObject *filename);"
         ),
         (
             "Include/internal/pycore_import.h",
             "!defined(Py_LIMITED_API) && defined(Py_GIL_DISABLED)",
             "extern int _PyImport_CheckGILForModule(PyObject *module, PyObject *module_name);"
         ),
         (
             "Include/internal/pycore_importdl.h",
             "",
             "extern void _Py_ext_module_loader_info_clear( struct _Py_ext_module_loader_info *info);"
         ),
         (
             "Include/internal/pycore_importdl.h",
             "",
             "extern int _Py_ext_module_loader_info_init( struct _Py_ext_module_loader_info *info, PyObject *name, PyObject *filename, _Py_ext_module_origin origin);"
         ),
         (
             "Include/internal/pycore_importdl.h",
             "",
             "extern int _Py_ext_module_loader_info_init_for_core( struct _Py_ext_module_loader_info *p_info, PyObject *name);"
         ),
         (
             "Include/internal/pycore_importdl.h",
             "",
             "extern int _Py_ext_module_loader_info_init_for_builtin( struct _Py_ext_module_loader_info *p_info, PyObject *name);"
         ),
         (
             "Include/internal/pycore_importdl.h",
             "defined(HAVE_DYNAMIC_LOADING)",
             "extern int _Py_ext_module_loader_info_init_from_spec( struct _Py_ext_module_loader_info *info, PyObject *spec);"
         ),
         (
             "Include/internal/pycore_importdl.h",
             "",
             "extern void _Py_ext_module_loader_result_clear( struct _Py_ext_module_loader_result *res);"
         ),
         (
             "Include/internal/pycore_importdl.h",
             "",
             "extern void _Py_ext_module_loader_result_apply_error( struct _Py_ext_module_loader_result *res, const char *name);"
         ),
         (
             "Include/internal/pycore_importdl.h",
             "defined(HAVE_DYNAMIC_LOADING)",
             "extern PyModInitFunction _PyImport_GetModInitFunc( struct _Py_ext_module_loader_info *info, FILE *fp);"
         ),
         (
             "Include/internal/pycore_importdl.h",
             "",
             "extern int _PyImport_RunModInitFunc( PyModInitFunction p0, struct _Py_ext_module_loader_info *info, struct _Py_ext_module_loader_result *p_res);"
         ),
         (
             "Include/internal/pycore_index_pool.h",
             "defined(Py_GIL_DISABLED)",
             "extern int32_t _PyIndexPool_AllocIndex(_PyIndexPool *indices);"
         ),
         (
             "Include/internal/pycore_index_pool.h",
             "defined(Py_GIL_DISABLED)",
             "extern void _PyIndexPool_FreeIndex(_PyIndexPool *indices, int32_t index);"
         ),
         (
             "Include/internal/pycore_index_pool.h",
             "defined(Py_GIL_DISABLED)",
             "extern void _PyIndexPool_Fini(_PyIndexPool *indices);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "PyAPI_FUNC(void) _PyErr_SetFromPyStatus(PyStatus status);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "!defined(NDEBUG)",
             "extern int _PyWideStringList_CheckConsistency(const PyWideStringList *list);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "extern void _PyWideStringList_Clear(PyWideStringList *list);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "extern int _PyWideStringList_Copy(PyWideStringList *list, const PyWideStringList *list2);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "extern PyStatus _PyWideStringList_Extend(PyWideStringList *list, const PyWideStringList *list2);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "extern PyObject* _PyWideStringList_AsList(const PyWideStringList *list);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "extern PyStatus _PyArgv_AsWstrList(const _PyArgv *args, PyWideStringList *list);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "extern int _Py_str_to_int( const char *str, int *result);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "extern const wchar_t* _Py_get_xoption( const PyWideStringList *xoptions, const wchar_t *name);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "extern const char* _Py_GetEnv( int use_environment, const char *name);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "extern void _Py_get_env_flag( int use_environment, int *flag, const char *name);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "extern void _Py_ClearArgcArgv(void);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "extern void _PyPreCmdline_Clear(_PyPreCmdline *cmdline);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "extern PyStatus _PyPreCmdline_SetArgv(_PyPreCmdline *cmdline, const _PyArgv *args);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "extern PyStatus _PyPreCmdline_SetConfig( const _PyPreCmdline *cmdline, PyConfig *config);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "extern PyStatus _PyPreCmdline_Read(_PyPreCmdline *cmdline, const PyPreConfig *preconfig);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "PyAPI_FUNC(void) _PyPreConfig_InitCompatConfig(PyPreConfig *preconfig);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "extern void _PyPreConfig_InitFromConfig( PyPreConfig *preconfig, const PyConfig *config);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "extern PyStatus _PyPreConfig_InitFromPreConfig( PyPreConfig *preconfig, const PyPreConfig *config2);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "extern PyObject* _PyPreConfig_AsDict(const PyPreConfig *preconfig);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "extern void _PyPreConfig_GetConfig(PyPreConfig *preconfig, const PyConfig *config);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "extern PyStatus _PyPreConfig_Read(PyPreConfig *preconfig, const _PyArgv *args);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "extern PyStatus _PyPreConfig_Write(const PyPreConfig *preconfig);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "PyAPI_FUNC(void) _PyConfig_InitCompatConfig(PyConfig *config);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "extern PyStatus _PyConfig_Copy( PyConfig *config, const PyConfig *config2);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "extern PyStatus _PyConfig_InitPathConfig( PyConfig *config, int compute_path_config);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "extern PyStatus _PyConfig_InitImportConfig(PyConfig *config);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "extern PyStatus _PyConfig_Read(PyConfig *config, int compute_path_config);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "extern PyStatus _PyConfig_Write(const PyConfig *config, _PyRuntimeState *runtime);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "extern PyStatus _PyConfig_SetPyArgv( PyConfig *config, const _PyArgv *args);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "extern PyObject* _PyConfig_CreateXOptionsDict(const PyConfig *config);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "extern void _Py_DumpPathConfig(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyConfig_AsDict(const PyConfig *config);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "PyAPI_FUNC(int) _PyConfig_FromDict(PyConfig *config, PyObject *dict);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "PyAPI_FUNC(PyObject*) _Py_Get_Getpath_CodeObject(void);"
         ),
         (
             "Include/internal/pycore_initconfig.h",
             "",
             "PyAPI_FUNC(PyObject*) _Py_GetConfigsAsDict(void);"
         ),
         (
             "Include/internal/pycore_instruction_sequence.h",
             "",
             "PyAPI_FUNC(PyObject*)_PyInstructionSequence_New(void);"
         ),
         (
             "Include/internal/pycore_instruction_sequence.h",
             "",
             "extern PyTypeObject _PyInstructionSequence_Type;"
         ),
         (
             "Include/internal/pycore_instruments.h",
             "",
             "extern PyObject _PyInstrumentation_MISSING;"
         ),
         (
             "Include/internal/pycore_instruments.h",
             "",
             "extern PyObject _PyInstrumentation_DISABLE;"
         ),
         (
             "Include/internal/pycore_interp.h",
             "",
             "extern void _PyInterpreterState_Clear(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_interp.h",
             "",
             "PyAPI_FUNC(int64_t) _PyInterpreterState_ObjectToID(PyObject *);"
         ),
         (
             "Include/internal/pycore_interp.h",
             "",
             "PyAPI_FUNC(PyInterpreterState *) _PyInterpreterState_LookUpID(int64_t);"
         ),
         (
             "Include/internal/pycore_interp.h",
             "",
             "PyAPI_FUNC(PyInterpreterState *) _PyInterpreterState_LookUpIDObject(PyObject *);"
         ),
         (
             "Include/internal/pycore_interp.h",
             "",
             "PyAPI_FUNC(void) _PyInterpreterState_IDIncref(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_interp.h",
             "",
             "PyAPI_FUNC(void) _PyInterpreterState_IDDecref(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_interp.h",
             "",
             "PyAPI_FUNC(int) _PyInterpreterState_IsReady(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_interp.h",
             "",
             "PyAPI_FUNC(long) _PyInterpreterState_GetWhence(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_interp.h",
             "",
             "extern void _PyInterpreterState_SetWhence( PyInterpreterState *interp, long whence);"
         ),
         (
             "Include/internal/pycore_interp.h",
             "",
             "extern int _PyInterpreterState_HasFeature(PyInterpreterState *interp, unsigned long feature);"
         ),
         (
             "Include/internal/pycore_interp.h",
             "",
             "PyAPI_FUNC(PyStatus) _PyInterpreterState_New( PyThreadState *tstate, PyInterpreterState **pinterp);"
         ),
         (
             "Include/internal/pycore_interp.h",
             "",
             "extern const PyConfig* _PyInterpreterState_GetConfig( PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_interpframe.h",
             "",
             "PyAPI_FUNC(void) _PyThreadState_PopFrame(PyThreadState *tstate, _PyInterpreterFrame *frame);"
         ),
         (
             "Include/internal/pycore_interpframe.h",
             "",
             "PyAPI_FUNC(_PyInterpreterFrame *) _PyEvalFramePushAndInit(PyThreadState *tstate, _PyStackRef func, PyObject *locals, _PyStackRef const *args, size_t argcount, PyObject *kwnames, _PyInterpreterFrame *previous);"
         ),
         (
             "Include/internal/pycore_interpolation.h",
             "",
             "extern PyTypeObject _PyInterpolation_Type;"
         ),
         (
             "Include/internal/pycore_interpolation.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyInterpolation_Build(PyObject *value, PyObject *str, int conversion, PyObject *format_spec);"
         ),
         (
             "Include/internal/pycore_interpolation.h",
             "",
             "extern PyStatus _PyInterpolation_InitTypes(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_interpolation.h",
             "",
             "extern PyObject *_PyInterpolation_GetValueRef(PyObject *interpolation);"
         ),
         (
             "Include/internal/pycore_intrinsics.h",
             "",
             "PyAPI_DATA(const intrinsic_func1_info) _PyIntrinsics_UnaryFunctions[];"
         ),
         (
             "Include/internal/pycore_intrinsics.h",
             "",
             "PyAPI_DATA(const intrinsic_func2_info) _PyIntrinsics_BinaryFunctions[];"
         ),
         (
             "Include/internal/pycore_list.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyList_Extend(PyListObject *, PyObject *);"
         ),
         (
             "Include/internal/pycore_list.h",
             "",
             "PyAPI_FUNC(PyObject) *_PyList_SliceSubscript(PyObject*, PyObject*);"
         ),
         (
             "Include/internal/pycore_list.h",
             "",
             "extern void _PyList_DebugMallocStats(FILE *out);"
         ),
         (
             "Include/internal/pycore_list.h",
             "",
             "extern PyObject* _PyList_GetItemRef(PyListObject *, Py_ssize_t i);"
         ),
         (
             "Include/internal/pycore_list.h",
             "defined(Py_GIL_DISABLED)",
             "extern int _PyList_GetItemRefNoLock(PyListObject *, Py_ssize_t, _PyStackRef *);"
         ),
         (
             "Include/internal/pycore_list.h",
             "",
             "PyAPI_FUNC(int) _PyList_AppendTakeRefListResize(PyListObject *self, PyObject *newitem);"
         ),
         (
             "Include/internal/pycore_list.h",
             "",
             "PyAPI_FUNC(PyObject *)_PyList_FromStackRefStealOnSuccess(const union _PyStackRef *src, Py_ssize_t n);"
         ),
         (
             "Include/internal/pycore_list.h",
             "",
             "PyAPI_FUNC(PyObject *)_PyList_AsTupleAndClear(PyListObject *v);"
         ),
         (
             "Include/internal/pycore_lock.h",
             "",
             "extern PyAPI_FUNC(PyLockStatus) _PyMutex_LockTimed(PyMutex *m, PyTime_t timeout_ns, _PyLockFlags flags);"
         ),
         (
             "Include/internal/pycore_lock.h",
             "",
             "extern int _PyMutex_TryUnlock(PyMutex *m);"
         ),
         (
             "Include/internal/pycore_lock.h",
             "",
             "PyAPI_FUNC(int) _PyEvent_IsSet(PyEvent *evt);"
         ),
         (
             "Include/internal/pycore_lock.h",
             "",
             "PyAPI_FUNC(void) _PyEvent_Notify(PyEvent *evt);"
         ),
         (
             "Include/internal/pycore_lock.h",
             "",
             "PyAPI_FUNC(void) PyEvent_Wait(PyEvent *evt);"
         ),
         (
             "Include/internal/pycore_lock.h",
             "",
             "PyAPI_FUNC(int) PyEvent_WaitTimed(PyEvent *evt, PyTime_t timeout_ns, int detach);"
         ),
         (
             "Include/internal/pycore_lock.h",
             "",
             "extern void _PyRawMutex_LockSlow(_PyRawMutex *m);"
         ),
         (
             "Include/internal/pycore_lock.h",
             "",
             "extern void _PyRawMutex_UnlockSlow(_PyRawMutex *m);"
         ),
         (
             "Include/internal/pycore_lock.h",
             "",
             "PyAPI_FUNC(int) _PyOnceFlag_CallOnceSlow(_PyOnceFlag *flag, _Py_once_fn_t *fn, void *arg);"
         ),
         (
             "Include/internal/pycore_lock.h",
             "",
             "PyAPI_FUNC(int) _PyRecursiveMutex_IsLockedByCurrentThread(_PyRecursiveMutex *m);"
         ),
         (
             "Include/internal/pycore_lock.h",
             "",
             "PyAPI_FUNC(void) _PyRecursiveMutex_Lock(_PyRecursiveMutex *m);"
         ),
         (
             "Include/internal/pycore_lock.h",
             "",
             "extern PyLockStatus _PyRecursiveMutex_LockTimed(_PyRecursiveMutex *m, PyTime_t timeout, _PyLockFlags flags);"
         ),
         (
             "Include/internal/pycore_lock.h",
             "",
             "PyAPI_FUNC(void) _PyRecursiveMutex_Unlock(_PyRecursiveMutex *m);"
         ),
         (
             "Include/internal/pycore_lock.h",
             "",
             "extern int _PyRecursiveMutex_TryUnlock(_PyRecursiveMutex *m);"
         ),
         (
             "Include/internal/pycore_lock.h",
             "",
             "PyAPI_FUNC(void) _PyRWMutex_RLock(_PyRWMutex *rwmutex);"
         ),
         (
             "Include/internal/pycore_lock.h",
             "",
             "PyAPI_FUNC(void) _PyRWMutex_RUnlock(_PyRWMutex *rwmutex);"
         ),
         (
             "Include/internal/pycore_lock.h",
             "",
             "PyAPI_FUNC(void) _PyRWMutex_Lock(_PyRWMutex *rwmutex);"
         ),
         (
             "Include/internal/pycore_lock.h",
             "",
             "PyAPI_FUNC(void) _PyRWMutex_Unlock(_PyRWMutex *rwmutex);"
         ),
         (
             "Include/internal/pycore_lock.h",
             "",
             "PyAPI_FUNC(void) _PySeqLock_LockWrite(_PySeqLock *seqlock);"
         ),
         (
             "Include/internal/pycore_lock.h",
             "",
             "PyAPI_FUNC(void) _PySeqLock_UnlockWrite(_PySeqLock *seqlock);"
         ),
         (
             "Include/internal/pycore_lock.h",
             "",
             "PyAPI_FUNC(void) _PySeqLock_AbandonWrite(_PySeqLock *seqlock);"
         ),
         (
             "Include/internal/pycore_lock.h",
             "",
             "PyAPI_FUNC(uint32_t) _PySeqLock_BeginRead(_PySeqLock *seqlock);"
         ),
         (
             "Include/internal/pycore_lock.h",
             "",
             "PyAPI_FUNC(int) _PySeqLock_EndRead(_PySeqLock *seqlock, uint32_t previous);"
         ),
         (
             "Include/internal/pycore_lock.h",
             "",
             "PyAPI_FUNC(int) _PySeqLock_AfterFork(_PySeqLock *seqlock);"
         ),
         (
             "Include/internal/pycore_long.h",
             "",
             "extern PyStatus _PyLong_InitTypes(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_long.h",
             "",
             "extern void _PyLong_FiniTypes(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_long.h",
             "",
             "PyAPI_FUNC(void) _PyLong_ExactDealloc(PyObject *self);"
         ),
         (
             "Include/internal/pycore_long.h",
             "",
             "PyAPI_DATA(double) _PyLong_Frexp(PyLongObject *a, int64_t *e);"
         ),
         (
             "Include/internal/pycore_long.h",
             "",
             "extern PyObject* _PyLong_FromBytes(const char *, Py_ssize_t, int);"
         ),
         (
             "Include/internal/pycore_long.h",
             "",
             "PyAPI_DATA(PyObject*) _PyLong_DivmodNear(PyObject *, PyObject *);"
         ),
         (
             "Include/internal/pycore_long.h",
             "",
             "PyAPI_DATA(PyObject*) _PyLong_Format(PyObject *obj, int base);"
         ),
         (
             "Include/internal/pycore_long.h",
             "",
             "PyAPI_DATA(PyObject*) _PyLong_Rshift(PyObject *, int64_t);"
         ),
         (
             "Include/internal/pycore_long.h",
             "",
             "PyAPI_DATA(PyObject*) _PyLong_Lshift(PyObject *, int64_t);"
         ),
         (
             "Include/internal/pycore_long.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyLong_Add(PyLongObject *left, PyLongObject *right);"
         ),
         (
             "Include/internal/pycore_long.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyLong_Multiply(PyLongObject *left, PyLongObject *right);"
         ),
         (
             "Include/internal/pycore_long.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyLong_Subtract(PyLongObject *left, PyLongObject *right);"
         ),
         (
             "Include/internal/pycore_long.h",
             "",
             "PyAPI_DATA(unsigned char) _PyLong_DigitValue[256];"
         ),
         (
             "Include/internal/pycore_long.h",
             "",
             "extern int _PyLong_FormatAdvancedWriter( _PyUnicodeWriter *writer, PyObject *obj, PyObject *format_spec, Py_ssize_t start, Py_ssize_t end);"
         ),
         (
             "Include/internal/pycore_long.h",
             "",
             "extern int _PyLong_FormatWriter( _PyUnicodeWriter *writer, PyObject *obj, int base, int alternate);"
         ),
         (
             "Include/internal/pycore_long.h",
             "",
             "extern char* _PyLong_FormatBytesWriter( _PyBytesWriter *writer, char *str, PyObject *obj, int base, int alternate);"
         ),
         (
             "Include/internal/pycore_long.h",
             "",
             "PyAPI_FUNC(int) _PyLong_UnsignedShort_Converter(PyObject *, void *);"
         ),
         (
             "Include/internal/pycore_long.h",
             "",
             "PyAPI_FUNC(int) _PyLong_UnsignedInt_Converter(PyObject *, void *);"
         ),
         (
             "Include/internal/pycore_long.h",
             "",
             "PyAPI_FUNC(int) _PyLong_UnsignedLong_Converter(PyObject *, void *);"
         ),
         (
             "Include/internal/pycore_long.h",
             "",
             "PyAPI_FUNC(int) _PyLong_UnsignedLongLong_Converter(PyObject *, void *);"
         ),
         (
             "Include/internal/pycore_long.h",
             "",
             "PyAPI_FUNC(int) _PyLong_Size_t_Converter(PyObject *, void *);"
         ),
         (
             "Include/internal/pycore_long.h",
             "",
             "PyAPI_FUNC(int) _PyLong_UInt8_Converter(PyObject *, void *);"
         ),
         (
             "Include/internal/pycore_long.h",
             "",
             "PyAPI_FUNC(int) _PyLong_UInt16_Converter(PyObject *, void *);"
         ),
         (
             "Include/internal/pycore_long.h",
             "",
             "PyAPI_FUNC(int) _PyLong_UInt32_Converter(PyObject *, void *);"
         ),
         (
             "Include/internal/pycore_long.h",
             "",
             "PyAPI_FUNC(int) _PyLong_UInt64_Converter(PyObject *, void *);"
         ),
         (
             "Include/internal/pycore_memoryobject.h",
             "",
             "extern PyTypeObject _PyManagedBuffer_Type;"
         ),
         (
             "Include/internal/pycore_modsupport.h",
             "",
             "extern int _PyArg_NoKwnames(const char *funcname, PyObject *kwnames);"
         ),
         (
             "Include/internal/pycore_modsupport.h",
             "",
             "PyAPI_FUNC(int) _PyArg_NoPositional(const char *funcname, PyObject *args);"
         ),
         (
             "Include/internal/pycore_modsupport.h",
             "",
             "PyAPI_FUNC(int) _PyArg_NoKeywords(const char *funcname, PyObject *kwargs);"
         ),
         (
             "Include/internal/pycore_modsupport.h",
             "",
             "PyAPI_FUNC(int) _PyArg_CheckPositional(const char *, Py_ssize_t, Py_ssize_t, Py_ssize_t);"
         ),
         (
             "Include/internal/pycore_modsupport.h",
             "",
             "extern PyObject ** _Py_VaBuildStack( PyObject **small_stack, Py_ssize_t small_stack_len, const char *format, va_list va, Py_ssize_t *p_nargs);"
         ),
         (
             "Include/internal/pycore_modsupport.h",
             "",
             "extern PyObject* _PyModule_CreateInitialized(PyModuleDef*, int apiver);"
         ),
         (
             "Include/internal/pycore_modsupport.h",
             "",
             "PyAPI_FUNC(int) _PyArg_ParseStack( PyObject *const *args, Py_ssize_t nargs, const char *format, ...);"
         ),
         (
             "Include/internal/pycore_modsupport.h",
             "",
             "extern int _PyArg_UnpackStack( PyObject *const *args, Py_ssize_t nargs, const char *name, Py_ssize_t min, Py_ssize_t max, ...);"
         ),
         (
             "Include/internal/pycore_modsupport.h",
             "",
             "PyAPI_FUNC(void) _PyArg_BadArgument( const char *fname, const char *displayname, const char *expected, PyObject *arg);"
         ),
         (
             "Include/internal/pycore_modsupport.h",
             "",
             "PyAPI_FUNC(int) _PyArg_ParseStackAndKeywords( PyObject *const *args, Py_ssize_t nargs, PyObject *kwnames, struct _PyArg_Parser *, ...);"
         ),
         (
             "Include/internal/pycore_modsupport.h",
             "",
             "PyAPI_FUNC(PyObject * const *) _PyArg_UnpackKeywords( PyObject *const *args, Py_ssize_t nargs, PyObject *kwargs, PyObject *kwnames, struct _PyArg_Parser *parser, int minpos, int maxpos, int minkw, int varpos, PyObject **buf);"
         ),
         (
             "Include/internal/pycore_moduleobject.h",
             "",
             "extern void _PyModule_Clear(PyObject *);"
         ),
         (
             "Include/internal/pycore_moduleobject.h",
             "",
             "extern void _PyModule_ClearDict(PyObject *);"
         ),
         (
             "Include/internal/pycore_moduleobject.h",
             "",
             "extern int _PyModuleSpec_IsInitializing(PyObject *);"
         ),
         (
             "Include/internal/pycore_moduleobject.h",
             "",
             "extern int _PyModuleSpec_GetFileOrigin(PyObject *, PyObject **);"
         ),
         (
             "Include/internal/pycore_moduleobject.h",
             "",
             "extern int _PyModule_IsPossiblyShadowing(PyObject *);"
         ),
         (
             "Include/internal/pycore_moduleobject.h",
             "",
             "extern int _PyModule_IsExtension(PyObject *obj);"
         ),
         (
             "Include/internal/pycore_moduleobject.h",
             "",
             "extern PyObject * _PyModule_GetFilenameObject(PyObject *);"
         ),
         (
             "Include/internal/pycore_moduleobject.h",
             "",
             "extern Py_ssize_t _PyModule_GetFilenameUTF8( PyObject *module, char *buffer, Py_ssize_t maxlen);"
         ),
         (
             "Include/internal/pycore_namespace.h",
             "",
             "extern PyTypeObject _PyNamespace_Type;"
         ),
         (
             "Include/internal/pycore_namespace.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyNamespace_New(PyObject *kwds);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "extern int _PyObject_CheckConsistency(PyObject *op, int check_content);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "extern void _PyDebugAllocatorStats(FILE *out, const char *block_name, int num_blocks, size_t sizeof_block);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "extern void _PyObject_DebugTypeStats(FILE *out);"
         ),
         (
             "Include/internal/pycore_object.h",
             "defined(Py_TRACE_REFS)",
             "extern void _Py_ForgetReference(PyObject *);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "PyAPI_FUNC(int) _PyObject_IsFreed(PyObject *);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "PyAPI_FUNC(void) _Py_NO_RETURN _Py_FatalRefcountErrorFunc( const char *func, const char *message);"
         ),
         (
             "Include/internal/pycore_object.h",
             "defined(Py_REF_DEBUG)",
             "PyAPI_DATA(Py_ssize_t) _Py_RefTotal;"
         ),
         (
             "Include/internal/pycore_object.h",
             "defined(Py_REF_DEBUG)",
             "extern void _Py_AddRefTotal(PyThreadState *, Py_ssize_t);"
         ),
         (
             "Include/internal/pycore_object.h",
             "defined(Py_REF_DEBUG)",
             "extern PyAPI_FUNC(void) _Py_IncRefTotal(PyThreadState *);"
         ),
         (
             "Include/internal/pycore_object.h",
             "defined(Py_REF_DEBUG)",
             "extern PyAPI_FUNC(void) _Py_DecRefTotal(PyThreadState *);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "PyAPI_FUNC(void) _Py_SetImmortal(PyObject *op);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "PyAPI_FUNC(void) _Py_SetImmortalUntracked(PyObject *op);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "extern int _PyType_CheckConsistency(PyTypeObject *type);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "extern int _PyDict_CheckConsistency(PyObject *mp, int check_content);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "extern void _PyType_InitCache(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "extern PyStatus _PyObject_InitState(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "extern void _PyObject_FiniState(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "extern bool _PyRefchain_IsTraced(PyInterpreterState *interp, PyObject *obj);"
         ),
         (
             "Include/internal/pycore_object.h",
             "defined(Py_GIL_DISABLED)",
             "extern PyAPI_FUNC(int) _PyObject_ResurrectEndSlow(PyObject *op);"
         ),
         (
             "Include/internal/pycore_object.h",
             "defined(Py_REF_DEBUG)",
             "extern void _PyInterpreterState_FinalizeRefTotal(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_object.h",
             "defined(Py_REF_DEBUG)",
             "extern void _Py_FinalizeRefTotal(_PyRuntimeState *);"
         ),
         (
             "Include/internal/pycore_object.h",
             "defined(Py_REF_DEBUG)",
             "extern void _PyDebug_PrintTotalRefs(void);"
         ),
         (
             "Include/internal/pycore_object.h",
             "defined(Py_TRACE_REFS)",
             "extern void _Py_AddToAllObjects(PyObject *op);"
         ),
         (
             "Include/internal/pycore_object.h",
             "defined(Py_TRACE_REFS)",
             "extern void _Py_PrintReferences(PyInterpreterState *, FILE *);"
         ),
         (
             "Include/internal/pycore_object.h",
             "defined(Py_TRACE_REFS)",
             "extern void _Py_PrintReferenceAddresses(PyInterpreterState *, FILE *);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "extern int _Py_CheckSlotResult( PyObject *obj, const char *slot_name, int success);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "extern PyObject* _PyType_AllocNoTrack(PyTypeObject *type, Py_ssize_t nitems);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyType_NewManagedObject(PyTypeObject *type);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "extern PyTypeObject* _PyType_CalculateMetaclass(PyTypeObject *, PyObject *);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "extern PyObject* _PyType_GetDocFromInternalDoc(const char *, const char *);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "extern PyObject* _PyType_GetTextSignatureFromInternalDoc(const char *, const char *, int);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "extern int _PyObject_SetAttributeErrorContext(PyObject *v, PyObject* name);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "extern int _PyObject_StoreInstanceAttribute(PyObject *obj, PyObject *name, PyObject *value);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "extern bool _PyObject_TryGetInstanceAttribute(PyObject *obj, PyObject *name, PyObject **attr);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "extern PyObject *_PyType_LookupRefAndVersion(PyTypeObject *, PyObject *, unsigned int *);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "extern int _PyObject_GetMethodStackRef(PyThreadState *ts, _PyStackRef *self, PyObject *name, _PyStackRef *method);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "extern int _PyType_CacheInitForSpecialization(PyHeapTypeObject *type, PyObject *init, unsigned int tp_version);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "extern PyObject ** _PyObject_ComputedDictPointer(PyObject *);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "extern int _PyObject_IsInstanceDictEmpty(PyObject *);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyObject_LookupSpecial(PyObject *, PyObject *);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "PyAPI_FUNC(int) _PyObject_LookupSpecialMethod(PyObject *attr, _PyStackRef *method_and_self);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyObject_MaybeCallSpecialNoArgs(PyObject *self, PyObject *attr);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyObject_MaybeCallSpecialOneArg(PyObject *self, PyObject *attr, PyObject *arg);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "extern int _PyObject_IsAbstract(PyObject *);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "PyAPI_FUNC(int) _PyObject_GetMethod(PyObject *obj, PyObject *name, PyObject **method);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "extern PyObject* _PyObject_NextNotImplemented(PyObject *);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyObject_GetState(PyObject *);"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "PyAPI_DATA(PyTypeObject) _PyNone_Type;"
         ),
         (
             "Include/internal/pycore_object.h",
             "",
             "PyAPI_DATA(PyTypeObject) _PyNotImplemented_Type;"
         ),
         ("Include/internal/pycore_object.h", "", "PyAPI_DATA(int) _Py_SwappedOp[];"),
         (
             "Include/internal/pycore_object.h",
             "",
             "extern void _Py_GetConstant_Init(void);"
         ),
         (
             "Include/internal/pycore_object_deferred.h",
             "",
             "extern void _PyObject_SetDeferredRefcount(PyObject *op);"
         ),
         (
             "Include/internal/pycore_obmalloc.h",
             "",
             "extern Py_ssize_t _Py_GetGlobalAllocatedBlocks(void);"
         ),
         (
             "Include/internal/pycore_obmalloc.h",
             "",
             "extern Py_ssize_t _PyInterpreterState_GetAllocatedBlocks(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_obmalloc.h",
             "",
             "extern void _PyInterpreterState_FinalizeAllocatedBlocks(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_obmalloc.h",
             "",
             "extern int _PyMem_init_obmalloc(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_obmalloc.h",
             "",
             "extern bool _PyMem_obmalloc_state_on_heap(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_obmalloc.h",
             "defined(WITH_PYMALLOC)",
             "PyAPI_FUNC(int) _PyObject_DebugMallocStats(FILE *out);"
         ),
         (
             "Include/internal/pycore_opcode_metadata.h",
             "",
             "extern int _PyOpcode_num_popped(int opcode, int oparg);"
         ),
         (
             "Include/internal/pycore_opcode_metadata.h",
             "",
             "extern int _PyOpcode_num_pushed(int opcode, int oparg);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "PyAPI_FUNC(_PyExecutorObject*) _Py_GetExecutor(PyCodeObject *code, int offset);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "PyAPI_FUNC(void) _Py_Executor_DependsOn(_PyExecutorObject *executor, void *obj);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "defined(_Py_TIER2)",
             "PyAPI_FUNC(void) _Py_Executors_InvalidateDependency(PyInterpreterState *interp, void *obj, int is_invalidation);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "defined(_Py_TIER2)",
             "PyAPI_FUNC(void) _Py_Executors_InvalidateAll(PyInterpreterState *interp, int is_invalidation);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "defined(_Py_TIER2)",
             "PyAPI_FUNC(void) _Py_Executors_InvalidateCold(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "extern PyTypeObject _PyUOpExecutor_Type;"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "extern bool _Py_uop_sym_is_null(JitOptSymbol *sym);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "extern bool _Py_uop_sym_is_not_null(JitOptSymbol *sym);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "extern bool _Py_uop_sym_is_const(JitOptContext *ctx, JitOptSymbol *sym);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "extern PyObject *_Py_uop_sym_get_const(JitOptContext *ctx, JitOptSymbol *sym);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "extern JitOptSymbol *_Py_uop_sym_new_unknown(JitOptContext *ctx);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "extern JitOptSymbol *_Py_uop_sym_new_not_null(JitOptContext *ctx);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "extern JitOptSymbol *_Py_uop_sym_new_type( JitOptContext *ctx, PyTypeObject *typ);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "extern JitOptSymbol *_Py_uop_sym_new_const(JitOptContext *ctx, PyObject *const_val);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "extern JitOptSymbol *_Py_uop_sym_new_null(JitOptContext *ctx);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "extern bool _Py_uop_sym_has_type(JitOptSymbol *sym);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "extern bool _Py_uop_sym_matches_type(JitOptSymbol *sym, PyTypeObject *typ);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "extern bool _Py_uop_sym_matches_type_version(JitOptSymbol *sym, unsigned int version);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "extern void _Py_uop_sym_set_null(JitOptContext *ctx, JitOptSymbol *sym);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "extern void _Py_uop_sym_set_non_null(JitOptContext *ctx, JitOptSymbol *sym);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "extern void _Py_uop_sym_set_type(JitOptContext *ctx, JitOptSymbol *sym, PyTypeObject *typ);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "extern bool _Py_uop_sym_set_type_version(JitOptContext *ctx, JitOptSymbol *sym, unsigned int version);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "extern void _Py_uop_sym_set_const(JitOptContext *ctx, JitOptSymbol *sym, PyObject *const_val);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "extern bool _Py_uop_sym_is_bottom(JitOptSymbol *sym);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "extern int _Py_uop_sym_truthiness(JitOptContext *ctx, JitOptSymbol *sym);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "extern PyTypeObject *_Py_uop_sym_get_type(JitOptSymbol *sym);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "extern bool _Py_uop_sym_is_immortal(JitOptSymbol *sym);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "extern JitOptSymbol *_Py_uop_sym_new_tuple(JitOptContext *ctx, int size, JitOptSymbol **args);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "extern JitOptSymbol *_Py_uop_sym_tuple_getitem(JitOptContext *ctx, JitOptSymbol *sym, int item);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "extern int _Py_uop_sym_tuple_length(JitOptSymbol *sym);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "extern JitOptSymbol *_Py_uop_sym_new_truthiness(JitOptContext *ctx, JitOptSymbol *value, bool truthy);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "extern void _Py_uop_abstractcontext_init(JitOptContext *ctx);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "extern void _Py_uop_abstractcontext_fini(JitOptContext *ctx);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "extern _Py_UOpsAbstractFrame *_Py_uop_frame_new( JitOptContext *ctx, PyCodeObject *co, int curr_stackentries, JitOptSymbol **args, int arg_len);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "extern int _Py_uop_frame_pop(JitOptContext *ctx);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "PyAPI_FUNC(PyObject *) _Py_uop_symbols_test(PyObject *self, PyObject *ignored);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "PyAPI_FUNC(int) _PyOptimizer_Optimize(_PyInterpreterFrame *frame, _Py_CODEUNIT *start, _PyExecutorObject **exec_ptr, int chain_depth);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "",
             "PyAPI_FUNC(int) _PyDumpExecutors(FILE *out);"
         ),
         (
             "Include/internal/pycore_optimizer.h",
             "defined(_Py_TIER2)",
             "extern void _Py_ClearExecutorDeletionList(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_parking_lot.h",
             "",
             "PyAPI_FUNC(int) _PyParkingLot_Park(const void *address, const void *expected, size_t address_size, PyTime_t timeout_ns, void *park_arg, int detach);"
         ),
         (
             "Include/internal/pycore_parking_lot.h",
             "",
             "PyAPI_FUNC(void) _PyParkingLot_Unpark(const void *address, _Py_unpark_fn_t *fn, void *arg);"
         ),
         (
             "Include/internal/pycore_parking_lot.h",
             "",
             "PyAPI_FUNC(void) _PyParkingLot_UnparkAll(const void *address);"
         ),
         (
             "Include/internal/pycore_parking_lot.h",
             "",
             "PyAPI_FUNC(void) _PyParkingLot_AfterFork(void);"
         ),
         (
             "Include/internal/pycore_parser.h",
             "",
             "extern struct _mod* _PyParser_ASTFromString( const char *str, PyObject* filename, int mode, PyCompilerFlags *flags, PyArena *arena);"
         ),
         (
             "Include/internal/pycore_parser.h",
             "",
             "extern struct _mod* _PyParser_ASTFromFile( FILE *fp, PyObject *filename_ob, const char *enc, int mode, const char *ps1, const char *ps2, PyCompilerFlags *flags, int *errcode, PyArena *arena);"
         ),
         (
             "Include/internal/pycore_parser.h",
             "",
             "extern struct _mod* _PyParser_InteractiveASTFromFile( FILE *fp, PyObject *filename_ob, const char *enc, int mode, const char *ps1, const char *ps2, PyCompilerFlags *flags, int *errcode, PyObject **interactive_src, PyArena *arena);"
         ),
         (
             "Include/internal/pycore_pathconfig.h",
             "",
             "PyAPI_FUNC(void) _PyPathConfig_ClearGlobal(void);"
         ),
         (
             "Include/internal/pycore_pathconfig.h",
             "",
             "extern PyStatus _PyPathConfig_ReadGlobal(PyConfig *config);"
         ),
         (
             "Include/internal/pycore_pathconfig.h",
             "",
             "extern PyStatus _PyPathConfig_UpdateGlobal(const PyConfig *config);"
         ),
         (
             "Include/internal/pycore_pathconfig.h",
             "",
             "extern const wchar_t * _PyPathConfig_GetGlobalModuleSearchPath(void);"
         ),
         (
             "Include/internal/pycore_pathconfig.h",
             "",
             "extern int _PyPathConfig_ComputeSysPath0( const PyWideStringList *argv, PyObject **path0);"
         ),
         (
             "Include/internal/pycore_pyarena.h",
             "",
             "PyAPI_FUNC(PyArena*) _PyArena_New(void);"
         ),
         (
             "Include/internal/pycore_pyarena.h",
             "",
             "PyAPI_FUNC(void) _PyArena_Free(PyArena *);"
         ),
         (
             "Include/internal/pycore_pyarena.h",
             "",
             "PyAPI_FUNC(void*) _PyArena_Malloc(PyArena *, size_t size);"
         ),
         (
             "Include/internal/pycore_pyarena.h",
             "",
             "PyAPI_FUNC(int) _PyArena_AddPyObject(PyArena *, PyObject *);"
         ),
         (
             "Include/internal/pycore_pybuffer.h",
             "",
             "PyAPI_FUNC(int) _PyBuffer_ReleaseInInterpreter( PyInterpreterState *interp, Py_buffer *view);"
         ),
         (
             "Include/internal/pycore_pybuffer.h",
             "",
             "PyAPI_FUNC(int) _PyBuffer_ReleaseInInterpreterAndRawFree( PyInterpreterState *interp, Py_buffer *view);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "extern _PyErr_StackItem* _PyErr_GetTopmostException(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "extern PyObject* _PyErr_GetHandledException(PyThreadState *);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "extern void _PyErr_SetHandledException(PyThreadState *, PyObject *);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "extern void _PyErr_GetExcInfo(PyThreadState *, PyObject **, PyObject **, PyObject **);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "PyAPI_FUNC(void) _PyErr_SetKeyError(PyObject *);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyErr_FormatFromCause( PyObject *exception, const char *format, ... );"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "extern int _PyException_AddNote( PyObject *exc, PyObject *note);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "extern int _PyErr_CheckSignals(void);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyErr_ProgramDecodedTextObject( PyObject *filename, int lineno, const char* encoding);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "extern PyObject* _PyUnicodeTranslateError_Create( PyObject *object, Py_ssize_t start, Py_ssize_t end, const char *reason );"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "extern void _Py_NO_RETURN _Py_FatalErrorFormat( const char *func, const char *format, ...);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "extern PyObject* _PyErr_SetImportErrorWithNameFrom( PyObject *, PyObject *, PyObject *, PyObject *);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "extern int _PyErr_SetModuleNotFoundError(PyObject *name);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "extern PyStatus _PyErr_InitTypes(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "extern void _PyErr_FiniTypes(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "extern PyObject* _PyErr_StackItemToExcInfoTuple( _PyErr_StackItem *err_info);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "extern void _PyErr_Fetch( PyThreadState *tstate, PyObject **type, PyObject **value, PyObject **traceback);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyErr_GetRaisedException(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "PyAPI_FUNC(int) _PyErr_ExceptionMatches( PyThreadState *tstate, PyObject *exc);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "PyAPI_FUNC(void) _PyErr_SetRaisedException(PyThreadState *tstate, PyObject *exc);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "extern void _PyErr_Restore( PyThreadState *tstate, PyObject *type, PyObject *value, PyObject *traceback);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "extern void _PyErr_SetObject( PyThreadState *tstate, PyObject *type, PyObject *value);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "extern void _PyErr_ChainStackItem(void);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "extern void _PyErr_ChainExceptions1Tstate(PyThreadState *, PyObject *);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "PyAPI_FUNC(void) _PyErr_Clear(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "extern void _PyErr_SetNone(PyThreadState *tstate, PyObject *exception);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "extern PyObject* _PyErr_NoMemory(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "extern int _PyErr_EmitSyntaxWarning(PyObject *msg, PyObject *filename, int lineno, int col_offset, int end_lineno, int end_col_offset);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "extern void _PyErr_RaiseSyntaxError(PyObject *msg, PyObject *filename, int lineno, int col_offset, int end_lineno, int end_col_offset);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "PyAPI_FUNC(void) _PyErr_SetString( PyThreadState *tstate, PyObject *exception, const char *string);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "PyAPI_FUNC(void) _PyErr_SetLocaleString( PyObject *exception, const char *string);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyErr_Format( PyThreadState *tstate, PyObject *exception, const char *format, ...);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyErr_FormatV( PyThreadState *tstate, PyObject *exception, const char *format, va_list vargs);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "extern void _PyErr_NormalizeException( PyThreadState *tstate, PyObject **exc, PyObject **val, PyObject **tb);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "extern PyObject* _PyErr_FormatFromCauseTstate( PyThreadState *tstate, PyObject *exception, const char *format, ...);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "extern PyObject* _PyExc_CreateExceptionGroup( const char *msg, PyObject *excs);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "extern PyObject* _PyExc_PrepReraiseStar( PyObject *orig, PyObject *excs);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "extern int _PyErr_CheckSignalsTstate(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "extern void _Py_DumpExtensionModules(int fd, PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "extern PyObject* _Py_CalculateSuggestions(PyObject *dir, PyObject *name);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "extern PyObject* _Py_Offer_Suggestions(PyObject* exception);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) _Py_UTF8_Edit_Cost(PyObject *str_a, PyObject *str_b, Py_ssize_t max_cost);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "PyAPI_FUNC(void) _PyErr_FormatNote(const char *format, ...);"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "PyAPI_DATA(PyTypeObject) _PyExc_IncompleteInputError;"
         ),
         (
             "Include/internal/pycore_pyerrors.h",
             "",
             "extern int _PyUnicodeError_GetParams( PyObject *self, PyObject **obj, Py_ssize_t *objlen, Py_ssize_t *start, Py_ssize_t *end, Py_ssize_t *slen, int as_bytes);"
         ),
         (
             "Include/internal/pycore_pyhash.h",
             "",
             "PyAPI_DATA(_Py_HashSecret_t) _Py_HashSecret;"
         ),
         (
             "Include/internal/pycore_pyhash.h",
             "defined(Py_DEBUG)",
             "extern int _Py_HashSecret_Initialized;"
         ),
         (
             "Include/internal/pycore_pyhash.h",
             "",
             "extern uint64_t _Py_KeyedHash(uint64_t key, const void *src, Py_ssize_t src_sz);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern int _Py_SetFileSystemEncoding( const char *encoding, const char *errors);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern void _Py_ClearFileSystemEncoding(void);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern PyStatus _PyUnicode_InitEncodings(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "defined(MS_WINDOWS)",
             "extern int _PyUnicode_EnableLegacyWindowsFSEncoding(void);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern int _Py_IsLocaleCoercionTarget(const char *ctype_loc);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern void _Py_InitVersion(void);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern PyStatus _PyFaulthandler_Init(int enable);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern PyObject * _PyBuiltin_Init(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern PyStatus _PySys_Create( PyThreadState *tstate, PyObject **sysmod_p);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern PyStatus _PySys_ReadPreinitWarnOptions(PyWideStringList *options);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern PyStatus _PySys_ReadPreinitXOptions(PyConfig *config);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern int _PySys_UpdateConfig(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern void _PySys_FiniTypes(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern int _PyBuiltins_AddExceptions(PyObject * bltinmod);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern PyStatus _Py_HashRandomization_Init(const PyConfig *);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern PyStatus _PyGC_Init(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern PyStatus _PyAtExit_Init(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern PyStatus _PyDateTime_InitTypes(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern int _PySignal_Init(int install_signal_handlers);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern void _PySignal_Fini(void);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern void _PyGC_Fini(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern void _Py_HashRandomization_Fini(void);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern void _PyFaulthandler_Fini(void);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern void _PyHash_Fini(void);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern void _PyTraceMalloc_Fini(void);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern void _PyWarnings_Fini(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern void _PyAST_Fini(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern void _PyAtExit_Fini(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern void _PyThread_FiniType(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern void _PyArg_Fini(void);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern void _Py_FinalizeAllocatedBlocks(_PyRuntimeState *);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern PyStatus _PyGILState_Init(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern void _PyGILState_SetTstate(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern void _PyGILState_Fini(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern void _PyGC_DumpShutdownStats(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern PyStatus _Py_PreInitializeFromPyArgv( const PyPreConfig *src_config, const struct _PyArgv *args);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern PyStatus _Py_PreInitializeFromConfig( const PyConfig *config, const struct _PyArgv *args);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern wchar_t * _Py_GetStdlibDir(void);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern int _Py_HandleSystemExitAndKeyboardInterrupt(int *exitcode_p);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern PyObject* _PyErr_WriteUnraisableDefaultHook(PyObject *unraisable);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern void _PyErr_Print(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern void _PyErr_Display(PyObject *file, PyObject *exception, PyObject *value, PyObject *tb);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern void _PyErr_DisplayException(PyObject *file, PyObject *exc);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern void _PyThreadState_DeleteCurrent(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern void _PyAtExit_Call(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern int _Py_IsCoreInitialized(void);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern int _Py_FdIsInteractive(FILE *fp, PyObject *filename);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern const char* _Py_gitidentifier(void);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern const char* _Py_gitversion(void);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "PyAPI_FUNC(int) _Py_IsInterpreterFinalizing(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern int _PyOS_URandom(void *buffer, Py_ssize_t size);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "PyAPI_FUNC(int) _PyOS_URandomNonblock(void *buffer, Py_ssize_t size);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern int _Py_CoerceLegacyLocale(int warn);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "extern int _Py_LegacyLocaleDetected(int warn);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "PyAPI_FUNC(char*) _Py_SetLocaleFromEnv(int category);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "PyAPI_FUNC(int) _PyInterpreterConfig_InitFromState( PyInterpreterConfig *, PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyInterpreterConfig_AsDict(PyInterpreterConfig *);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "PyAPI_FUNC(int) _PyInterpreterConfig_InitFromDict( PyInterpreterConfig *, PyObject *);"
         ),
         (
             "Include/internal/pycore_pylifecycle.h",
             "",
             "PyAPI_FUNC(int) _PyInterpreterConfig_UpdateFromDict( PyInterpreterConfig *, PyObject *);"
         ),
         (
             "Include/internal/pycore_pymath.h",
             "defined(HAVE_GCC_ASM_FOR_X87)",
             "extern unsigned short _Py_get_387controlword(void);"
         ),
         (
             "Include/internal/pycore_pymath.h",
             "defined(HAVE_GCC_ASM_FOR_X87)",
             "extern void _Py_set_387controlword(unsigned short);"
         ),
         (
             "Include/internal/pycore_pymem.h",
             "",
             "PyAPI_FUNC(const char*) _PyMem_GetCurrentAllocatorName(void);"
         ),
         (
             "Include/internal/pycore_pymem.h",
             "",
             "extern char* _PyMem_RawStrdup(const char *str);"
         ),
         (
             "Include/internal/pycore_pymem.h",
             "",
             "PyAPI_FUNC(char*) _PyMem_Strdup(const char *str);"
         ),
         (
             "Include/internal/pycore_pymem.h",
             "",
             "extern wchar_t* _PyMem_RawWcsdup(const wchar_t *str);"
         ),
         (
             "Include/internal/pycore_pymem.h",
             "",
             "extern int _PyMem_GetAllocatorName( const char *name, PyMemAllocatorName *allocator);"
         ),
         (
             "Include/internal/pycore_pymem.h",
             "",
             "extern int _PyMem_SetupAllocators(PyMemAllocatorName allocator);"
         ),
         (
             "Include/internal/pycore_pymem.h",
             "",
             "extern void *_PyMem_DefaultRawMalloc(size_t);"
         ),
         (
             "Include/internal/pycore_pymem.h",
             "",
             "extern void *_PyMem_DefaultRawCalloc(size_t, size_t);"
         ),
         (
             "Include/internal/pycore_pymem.h",
             "",
             "extern void *_PyMem_DefaultRawRealloc(void *, size_t);"
         ),
         (
             "Include/internal/pycore_pymem.h",
             "",
             "extern void _PyMem_DefaultRawFree(void *);"
         ),
         (
             "Include/internal/pycore_pymem.h",
             "",
             "extern wchar_t *_PyMem_DefaultRawWcsdup(const wchar_t *str);"
         ),
         (
             "Include/internal/pycore_pymem.h",
             "",
             "extern int _PyMem_DebugEnabled(void);"
         ),
         (
             "Include/internal/pycore_pymem.h",
             "",
             "extern void _PyMem_FreeDelayed(void *ptr, size_t size);"
         ),
         (
             "Include/internal/pycore_pymem.h",
             "defined(Py_GIL_DISABLED)",
             "PyAPI_FUNC(void) _PyObject_XDecRefDelayed(PyObject *obj);"
         ),
         (
             "Include/internal/pycore_pymem.h",
             "",
             "extern void _PyMem_ProcessDelayed(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_pymem.h",
             "",
             "extern void _PyMem_ProcessDelayedNoDealloc(PyThreadState *tstate, delayed_dealloc_cb cb, void *state);"
         ),
         (
             "Include/internal/pycore_pymem.h",
             "",
             "extern void _PyMem_AbandonDelayed(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_pymem.h",
             "",
             "extern void _PyMem_FiniDelayed(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_pymem_init.h",
             "",
             "extern void * _PyMem_RawMalloc(void *, size_t);"
         ),
         (
             "Include/internal/pycore_pymem_init.h",
             "",
             "extern void * _PyMem_RawCalloc(void *, size_t, size_t);"
         ),
         (
             "Include/internal/pycore_pymem_init.h",
             "",
             "extern void * _PyMem_RawRealloc(void *, void *, size_t);"
         ),
         (
             "Include/internal/pycore_pymem_init.h",
             "",
             "extern void _PyMem_RawFree(void *, void *);"
         ),
         (
             "Include/internal/pycore_pymem_init.h",
             "defined(Py_GIL_DISABLED)",
             "extern void* _PyObject_MiMalloc(void *, size_t);"
         ),
         (
             "Include/internal/pycore_pymem_init.h",
             "defined(Py_GIL_DISABLED)",
             "extern void* _PyObject_MiCalloc(void *, size_t, size_t);"
         ),
         (
             "Include/internal/pycore_pymem_init.h",
             "defined(Py_GIL_DISABLED)",
             "extern void _PyObject_MiFree(void *, void *);"
         ),
         (
             "Include/internal/pycore_pymem_init.h",
             "defined(Py_GIL_DISABLED)",
             "extern void* _PyObject_MiRealloc(void *, void *, size_t);"
         ),
         (
             "Include/internal/pycore_pymem_init.h",
             "defined(Py_GIL_DISABLED)",
             "extern void* _PyMem_MiMalloc(void *, size_t);"
         ),
         (
             "Include/internal/pycore_pymem_init.h",
             "defined(Py_GIL_DISABLED)",
             "extern void* _PyMem_MiCalloc(void *, size_t, size_t);"
         ),
         (
             "Include/internal/pycore_pymem_init.h",
             "defined(Py_GIL_DISABLED)",
             "extern void _PyMem_MiFree(void *, void *);"
         ),
         (
             "Include/internal/pycore_pymem_init.h",
             "defined(Py_GIL_DISABLED)",
             "extern void* _PyMem_MiRealloc(void *, void *, size_t);"
         ),
         (
             "Include/internal/pycore_pymem_init.h",
             "!defined(Py_GIL_DISABLED) && defined(WITH_PYMALLOC)",
             "extern void* _PyObject_Malloc(void *, size_t);"
         ),
         (
             "Include/internal/pycore_pymem_init.h",
             "!defined(Py_GIL_DISABLED) && defined(WITH_PYMALLOC)",
             "extern void* _PyObject_Calloc(void *, size_t, size_t);"
         ),
         (
             "Include/internal/pycore_pymem_init.h",
             "!defined(Py_GIL_DISABLED) && defined(WITH_PYMALLOC)",
             "extern void _PyObject_Free(void *, void *);"
         ),
         (
             "Include/internal/pycore_pymem_init.h",
             "!defined(Py_GIL_DISABLED) && defined(WITH_PYMALLOC)",
             "extern void* _PyObject_Realloc(void *, void *, size_t);"
         ),
         (
             "Include/internal/pycore_pymem_init.h",
             "",
             "extern void* _PyMem_DebugRawMalloc(void *, size_t);"
         ),
         (
             "Include/internal/pycore_pymem_init.h",
             "",
             "extern void* _PyMem_DebugRawCalloc(void *, size_t, size_t);"
         ),
         (
             "Include/internal/pycore_pymem_init.h",
             "",
             "extern void* _PyMem_DebugRawRealloc(void *, void *, size_t);"
         ),
         (
             "Include/internal/pycore_pymem_init.h",
             "",
             "extern void _PyMem_DebugRawFree(void *, void *);"
         ),
         (
             "Include/internal/pycore_pymem_init.h",
             "",
             "extern void* _PyMem_DebugMalloc(void *, size_t);"
         ),
         (
             "Include/internal/pycore_pymem_init.h",
             "",
             "extern void* _PyMem_DebugCalloc(void *, size_t, size_t);"
         ),
         (
             "Include/internal/pycore_pymem_init.h",
             "",
             "extern void* _PyMem_DebugRealloc(void *, void *, size_t);"
         ),
         (
             "Include/internal/pycore_pymem_init.h",
             "",
             "extern void _PyMem_DebugFree(void *, void *);"
         ),
         (
             "Include/internal/pycore_pymem_init.h",
             "",
             "extern void * _PyMem_ArenaAlloc(void *, size_t);"
         ),
         (
             "Include/internal/pycore_pymem_init.h",
             "",
             "extern void _PyMem_ArenaFree(void *, void *, size_t);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "extern int _Py_IsMainThread(void);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "PyAPI_FUNC(PyInterpreterState*) _PyInterpreterState_Main(void);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "extern int _Py_IsMainInterpreterFinalizing(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyInterpreterState_GetIDObject(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "PyAPI_FUNC(int) _PyInterpreterState_SetRunningMain(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "PyAPI_FUNC(void) _PyInterpreterState_SetNotRunningMain(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "PyAPI_FUNC(int) _PyInterpreterState_IsRunningMain(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "PyAPI_FUNC(void) _PyErr_SetInterpreterAlreadyRunning(void);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "extern int _PyThreadState_IsRunningMain(PyThreadState *);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "extern void _PyInterpreterState_ReinitRunningMain(PyThreadState *);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "extern const PyConfig* _Py_GetMainConfig(void);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "!defined(NDEBUG)",
             "extern int _PyThreadState_CheckConsistency(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "extern int _PyThreadState_MustExit(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "extern void _PyThreadState_HangThread(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "PyAPI_FUNC(PyThreadState *) _PyThreadState_GetCurrent(void);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "extern void _PyThreadState_Attach(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "extern void _PyThreadState_Detach(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "extern void _PyThreadState_Suspend(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "extern void _PyThreadState_SetShuttingDown(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "extern void _PyEval_StopTheWorldAll(_PyRuntimeState *runtime);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "extern void _PyEval_StartTheWorldAll(_PyRuntimeState *runtime);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "extern PyAPI_FUNC(void) _PyEval_StopTheWorld(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "extern PyAPI_FUNC(void) _PyEval_StartTheWorld(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "PyAPI_FUNC(PyThreadState *) _PyThreadState_New( PyInterpreterState *interp, int whence);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "extern void _PyThreadState_Bind(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "PyAPI_FUNC(PyThreadState *) _PyThreadState_NewBound( PyInterpreterState *interp, int whence);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "extern PyThreadState * _PyThreadState_RemoveExcept(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "extern void _PyThreadState_DeleteList(PyThreadState *list, int is_after_fork);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "extern void _PyThreadState_ClearMimallocHeaps(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyThreadState_GetDict(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "extern PyObject* _PyThread_CurrentExceptions(void);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "extern PyThreadState * _PyThreadState_Swap( _PyRuntimeState *runtime, PyThreadState *newts);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "extern PyStatus _PyInterpreterState_Enable(_PyRuntimeState *runtime);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "defined(HAVE_FORK)",
             "extern PyStatus _PyInterpreterState_DeleteExceptMain(_PyRuntimeState *runtime);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "defined(HAVE_FORK)",
             "extern void _PySignal_AfterFork(void);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "PyAPI_FUNC(int) _PyState_AddModule( PyThreadState *tstate, PyObject* module, PyModuleDef* def);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "extern int _PyOS_InterruptOccurred(PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "PyAPI_FUNC(const PyConfig*) _Py_GetConfig(void);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "extern PyInterpreterState* _PyGILState_GetInterpreterStateUnsafe(void);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "extern PyObject * _Py_GetMainModule(PyThreadState *);"
         ),
         (
             "Include/internal/pycore_pystate.h",
             "",
             "extern int _Py_CheckMainModule(PyObject *module);"
         ),
         (
             "Include/internal/pycore_pystats.h",
             "defined(Py_STATS)",
             "extern void _Py_StatsOn(void);"
         ),
         (
             "Include/internal/pycore_pystats.h",
             "defined(Py_STATS)",
             "extern void _Py_StatsOff(void);"
         ),
         (
             "Include/internal/pycore_pystats.h",
             "defined(Py_STATS)",
             "extern void _Py_StatsClear(void);"
         ),
         (
             "Include/internal/pycore_pystats.h",
             "defined(Py_STATS)",
             "extern int _Py_PrintSpecializationStats(int to_file);"
         ),
         (
             "Include/internal/pycore_pythonrun.h",
             "",
             "extern int _PyRun_SimpleFileObject( FILE *fp, PyObject *filename, int closeit, PyCompilerFlags *flags);"
         ),
         (
             "Include/internal/pycore_pythonrun.h",
             "",
             "extern int _PyRun_AnyFileObject( FILE *fp, PyObject *filename, int closeit, PyCompilerFlags *flags);"
         ),
         (
             "Include/internal/pycore_pythonrun.h",
             "",
             "extern int _PyRun_InteractiveLoopObject( FILE *fp, PyObject *filename, PyCompilerFlags *flags);"
         ),
         (
             "Include/internal/pycore_pythonrun.h",
             "",
             "extern int _PyObject_SupportedAsScript(PyObject *);"
         ),
         (
             "Include/internal/pycore_pythonrun.h",
             "",
             "extern const char* _Py_SourceAsString( PyObject *cmd, const char *funcname, const char *what, PyCompilerFlags *cf, PyObject **cmd_copy);"
         ),
         (
             "Include/internal/pycore_pythread.h",
             "defined(HAVE_FORK)",
             "extern int _PyThread_at_fork_reinit(PyThread_type_lock *lock);"
         ),
         (
             "Include/internal/pycore_pythread.h",
             "defined(HAVE_FORK)",
             "extern void _PyThread_AfterFork(struct _pythread_runtime_state *state);"
         ),
         (
             "Include/internal/pycore_pythread.h",
             "",
             "PyAPI_FUNC(int) PyThread_ParseTimeoutArg( PyObject *arg, int blocking, PY_TIMEOUT_T *timeout);"
         ),
         (
             "Include/internal/pycore_pythread.h",
             "",
             "PyAPI_FUNC(PyLockStatus) PyThread_acquire_lock_timed_with_retries( PyThread_type_lock, PY_TIMEOUT_T microseconds);"
         ),
         (
             "Include/internal/pycore_pythread.h",
             "",
             "PyAPI_FUNC(PyThread_ident_t) PyThread_get_thread_ident_ex(void);"
         ),
         (
             "Include/internal/pycore_pythread.h",
             "",
             "PyAPI_FUNC(int) PyThread_start_joinable_thread(void (*func)(void *), void *arg, PyThread_ident_t* ident, PyThread_handle_t* handle);"
         ),
         (
             "Include/internal/pycore_pythread.h",
             "",
             "PyAPI_FUNC(int) PyThread_join_thread(PyThread_handle_t);"
         ),
         (
             "Include/internal/pycore_pythread.h",
             "",
             "PyAPI_FUNC(int) PyThread_detach_thread(PyThread_handle_t);"
         ),
         (
             "Include/internal/pycore_runtime.h",
             "",
             "PyAPI_DATA(_PyRuntimeState) _PyRuntime;"
         ),
         (
             "Include/internal/pycore_runtime.h",
             "",
             "extern PyStatus _PyRuntimeState_Init(_PyRuntimeState *runtime);"
         ),
         (
             "Include/internal/pycore_runtime.h",
             "",
             "extern void _PyRuntimeState_Fini(_PyRuntimeState *runtime);"
         ),
         (
             "Include/internal/pycore_runtime.h",
             "defined(HAVE_FORK)",
             "extern PyStatus _PyRuntimeState_ReInitThreads(_PyRuntimeState *runtime);"
         ),
         (
             "Include/internal/pycore_runtime.h",
             "",
             "extern PyStatus _PyRuntime_Initialize(void);"
         ),
         (
             "Include/internal/pycore_runtime.h",
             "",
             "extern void _PyRuntime_Finalize(void);"
         ),
         (
             "Include/internal/pycore_runtime_init.h",
             "",
             "extern PyTypeObject _PyExc_MemoryError;"
         ),
         (
             "Include/internal/pycore_semaphore.h",
             "",
             "PyAPI_FUNC(int) _PySemaphore_Wait(_PySemaphore *sema, PyTime_t timeout_ns, int detach);"
         ),
         (
             "Include/internal/pycore_semaphore.h",
             "",
             "PyAPI_FUNC(void) _PySemaphore_Wakeup(_PySemaphore *sema);"
         ),
         (
             "Include/internal/pycore_semaphore.h",
             "",
             "PyAPI_FUNC(void) _PySemaphore_Init(_PySemaphore *sema);"
         ),
         (
             "Include/internal/pycore_semaphore.h",
             "",
             "PyAPI_FUNC(void) _PySemaphore_Destroy(_PySemaphore *sema);"
         ),
         (
             "Include/internal/pycore_setobject.h",
             "",
             "PyAPI_FUNC(int) _PySet_NextEntry( PyObject *set, Py_ssize_t *pos, PyObject **key, Py_hash_t *hash);"
         ),
         (
             "Include/internal/pycore_setobject.h",
             "",
             "PyAPI_FUNC(int) _PySet_NextEntryRef( PyObject *set, Py_ssize_t *pos, PyObject **key, Py_hash_t *hash);"
         ),
         (
             "Include/internal/pycore_setobject.h",
             "",
             "PyAPI_FUNC(int) _PySet_Update(PyObject *set, PyObject *iterable);"
         ),
         (
             "Include/internal/pycore_setobject.h",
             "",
             "PyAPI_DATA(PyObject *) _PySet_Dummy;"
         ),
         (
             "Include/internal/pycore_setobject.h",
             "",
             "PyAPI_FUNC(int) _PySet_Contains(PySetObject *so, PyObject *key);"
         ),
         (
             "Include/internal/pycore_setobject.h",
             "",
             "extern void _PySet_ClearInternal(PySetObject *so);"
         ),
         (
             "Include/internal/pycore_setobject.h",
             "",
             "PyAPI_FUNC(int) _PySet_AddTakeRef(PySetObject *so, PyObject *key);"
         ),
         (
             "Include/internal/pycore_signal.h",
             "",
             "PyAPI_FUNC(void) _Py_RestoreSignals(void);"
         ),
         (
             "Include/internal/pycore_signal.h",
             "",
             "PyAPI_FUNC(int) _PyOS_IsMainThread(void);"
         ),
         (
             "Include/internal/pycore_signal.h",
             "defined(MS_WINDOWS)",
             "PyAPI_FUNC(void*) _PyOS_SigintEvent(void);"
         ),
         (
             "Include/internal/pycore_sliceobject.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyBuildSlice_ConsumeRefs(PyObject *start, PyObject *stop);"
         ),
         (
             "Include/internal/pycore_stackref.h",
             "(!defined(Py_GIL_DISABLED) && defined(Py_STACKREF_DEBUG))",
             "PyAPI_FUNC(PyObject *) _Py_stackref_get_object(_PyStackRef ref);"
         ),
         (
             "Include/internal/pycore_stackref.h",
             "(!defined(Py_GIL_DISABLED) && defined(Py_STACKREF_DEBUG))",
             "PyAPI_FUNC(PyObject *) _Py_stackref_close(_PyStackRef ref, const char *filename, int linenumber);"
         ),
         (
             "Include/internal/pycore_stackref.h",
             "(!defined(Py_GIL_DISABLED) && defined(Py_STACKREF_DEBUG))",
             "PyAPI_FUNC(_PyStackRef) _Py_stackref_create(PyObject *obj, const char *filename, int linenumber);"
         ),
         (
             "Include/internal/pycore_stackref.h",
             "(!defined(Py_GIL_DISABLED) && defined(Py_STACKREF_DEBUG))",
             "PyAPI_FUNC(void) _Py_stackref_record_borrow(_PyStackRef ref, const char *filename, int linenumber);"
         ),
         (
             "Include/internal/pycore_stackref.h",
             "(!defined(Py_GIL_DISABLED) && defined(Py_STACKREF_DEBUG))",
             "extern void _Py_stackref_associate(PyInterpreterState *interp, PyObject *obj, _PyStackRef ref);"
         ),
         (
             "Include/internal/pycore_stackref.h",
             "(!defined(Py_GIL_DISABLED) && defined(Py_STACKREF_DEBUG))",
             "extern void _PyStackRef_CLOSE_SPECIALIZED(_PyStackRef ref, destructor destruct, const char *filename, int linenumber);"
         ),
         (
             "Include/internal/pycore_stackref.h",
             "(!defined(Py_GIL_DISABLED) && defined(Py_STACKREF_DEBUG))",
             "extern int PyStackRef_Is(_PyStackRef a, _PyStackRef b);"
         ),
         (
             "Include/internal/pycore_stackref.h",
             "(!defined(Py_GIL_DISABLED) && defined(Py_STACKREF_DEBUG))",
             "extern bool PyStackRef_IsTaggedInt(_PyStackRef ref);"
         ),
         (
             "Include/internal/pycore_stackref.h",
             "(!defined(Py_GIL_DISABLED) && defined(Py_STACKREF_DEBUG))",
             "extern intptr_t PyStackRef_UntagInt(_PyStackRef ref);"
         ),
         (
             "Include/internal/pycore_stackref.h",
             "(!defined(Py_GIL_DISABLED) && defined(Py_STACKREF_DEBUG))",
             "extern _PyStackRef PyStackRef_TagInt(intptr_t i);"
         ),
         (
             "Include/internal/pycore_stats.h",
             "defined(Py_STATS)",
             "PyAPI_FUNC(PyObject*) _Py_GetSpecializationStats(void);"
         ),
         (
             "Include/internal/pycore_strhex.h",
             "",
             "PyAPI_FUNC(PyObject*) _Py_strhex(const char* argbuf, const Py_ssize_t arglen);"
         ),
         (
             "Include/internal/pycore_strhex.h",
             "",
             "extern PyObject* _Py_strhex_bytes( const char* argbuf, const Py_ssize_t arglen);"
         ),
         (
             "Include/internal/pycore_strhex.h",
             "",
             "extern PyObject* _Py_strhex_with_sep( const char* argbuf, const Py_ssize_t arglen, PyObject* sep, const int bytes_per_group);"
         ),
         (
             "Include/internal/pycore_strhex.h",
             "",
             "PyAPI_FUNC(PyObject*) _Py_strhex_bytes_with_sep( const char* argbuf, const Py_ssize_t arglen, PyObject* sep, const int bytes_per_group);"
         ),
         (
             "Include/internal/pycore_structseq.h",
             "",
             "PyAPI_FUNC(PyTypeObject*) _PyStructSequence_NewType( PyStructSequence_Desc *desc, unsigned long tp_flags);"
         ),
         (
             "Include/internal/pycore_structseq.h",
             "",
             "extern int _PyStructSequence_InitBuiltinWithFlags( PyInterpreterState *interp, PyTypeObject *type, PyStructSequence_Desc *desc, unsigned long tp_flags);"
         ),
         (
             "Include/internal/pycore_structseq.h",
             "",
             "extern void _PyStructSequence_FiniBuiltin( PyInterpreterState *interp, PyTypeObject *type);"
         ),
         (
             "Include/internal/pycore_symtable.h",
             "",
             "extern PyTypeObject PySTEntry_Type;"
         ),
         (
             "Include/internal/pycore_symtable.h",
             "",
             "extern long _PyST_GetSymbol(PySTEntryObject *, PyObject *);"
         ),
         (
             "Include/internal/pycore_symtable.h",
             "",
             "extern int _PyST_GetScope(PySTEntryObject *, PyObject *);"
         ),
         (
             "Include/internal/pycore_symtable.h",
             "",
             "extern int _PyST_IsFunctionLike(PySTEntryObject *);"
         ),
         (
             "Include/internal/pycore_symtable.h",
             "",
             "extern struct symtable* _PySymtable_Build( struct _mod *mod, PyObject *filename, _PyFutureFeatures *future);"
         ),
         (
             "Include/internal/pycore_symtable.h",
             "",
             "extern PySTEntryObject* _PySymtable_Lookup(struct symtable *, void *);"
         ),
         (
             "Include/internal/pycore_symtable.h",
             "",
             "extern int _PySymtable_LookupOptional(struct symtable *, void *, PySTEntryObject **);"
         ),
         (
             "Include/internal/pycore_symtable.h",
             "",
             "extern void _PySymtable_Free(struct symtable *);"
         ),
         (
             "Include/internal/pycore_symtable.h",
             "",
             "extern PyObject *_Py_MaybeMangle(PyObject *privateobj, PySTEntryObject *ste, PyObject *name);"
         ),
         (
             "Include/internal/pycore_symtable.h",
             "",
             "extern PyObject* _Py_Mangle(PyObject *p, PyObject *name);"
         ),
         (
             "Include/internal/pycore_symtable.h",
             "",
             "extern struct symtable* _Py_SymtableStringObjectFlags( const char *str, PyObject *filename, int start, PyCompilerFlags *flags);"
         ),
         (
             "Include/internal/pycore_sysmodule.h",
             "",
             "PyAPI_FUNC(int) _PySys_GetOptionalAttr(PyObject *, PyObject **);"
         ),
         (
             "Include/internal/pycore_sysmodule.h",
             "",
             "PyAPI_FUNC(int) _PySys_GetOptionalAttrString(const char *, PyObject **);"
         ),
         (
             "Include/internal/pycore_sysmodule.h",
             "",
             "PyAPI_FUNC(PyObject *) _PySys_GetRequiredAttr(PyObject *);"
         ),
         (
             "Include/internal/pycore_sysmodule.h",
             "",
             "PyAPI_FUNC(PyObject *) _PySys_GetRequiredAttrString(const char *);"
         ),
         (
             "Include/internal/pycore_sysmodule.h",
             "",
             "PyAPI_FUNC(size_t) _PySys_GetSizeOf(PyObject *);"
         ),
         (
             "Include/internal/pycore_sysmodule.h",
             "",
             "extern int _PySys_SetAttr(PyObject *, PyObject *);"
         ),
         (
             "Include/internal/pycore_sysmodule.h",
             "",
             "extern int _PySys_ClearAttrString(PyInterpreterState *interp, const char *name, int verbose);"
         ),
         (
             "Include/internal/pycore_sysmodule.h",
             "",
             "extern int _PySys_SetFlagObj(Py_ssize_t pos, PyObject *new_value);"
         ),
         (
             "Include/internal/pycore_sysmodule.h",
             "",
             "extern int _PySys_SetIntMaxStrDigits(int maxdigits);"
         ),
         (
             "Include/internal/pycore_sysmodule.h",
             "",
             "extern int _PySysRemoteDebug_SendExec(int pid, int tid, const char *debugger_script_path);"
         ),
         (
             "Include/internal/pycore_template.h",
             "",
             "extern PyTypeObject _PyTemplate_Type;"
         ),
         (
             "Include/internal/pycore_template.h",
             "",
             "extern PyTypeObject _PyTemplateIter_Type;"
         ),
         (
             "Include/internal/pycore_template.h",
             "",
             "extern PyObject *_PyTemplate_Concat(PyObject *self, PyObject *other);"
         ),
         (
             "Include/internal/pycore_template.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyTemplate_Build(PyObject *strings, PyObject *interpolations);"
         ),
         (
             "Include/internal/pycore_time.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyLong_FromTime_t(time_t sec);"
         ),
         (
             "Include/internal/pycore_time.h",
             "",
             "PyAPI_FUNC(time_t) _PyLong_AsTime_t(PyObject *obj);"
         ),
         (
             "Include/internal/pycore_time.h",
             "",
             "PyAPI_FUNC(int) _PyTime_ObjectToTime_t( PyObject *obj, time_t *sec, _PyTime_round_t);"
         ),
         (
             "Include/internal/pycore_time.h",
             "",
             "PyAPI_FUNC(int) _PyTime_ObjectToTimeval( PyObject *obj, time_t *sec, long *usec, _PyTime_round_t);"
         ),
         (
             "Include/internal/pycore_time.h",
             "",
             "PyAPI_FUNC(int) _PyTime_ObjectToTimespec( PyObject *obj, time_t *sec, long *nsec, _PyTime_round_t);"
         ),
         (
             "Include/internal/pycore_time.h",
             "",
             "PyAPI_FUNC(PyTime_t) _PyTime_FromSeconds(int seconds);"
         ),
         (
             "Include/internal/pycore_time.h",
             "",
             "extern int _PyTime_FromSecondsDouble( double seconds, _PyTime_round_t round, PyTime_t *result);"
         ),
         (
             "Include/internal/pycore_time.h",
             "",
             "extern PyTime_t _PyTime_FromMicrosecondsClamp(PyTime_t us);"
         ),
         (
             "Include/internal/pycore_time.h",
             "",
             "PyAPI_FUNC(int) _PyTime_FromLong(PyTime_t *t, PyObject *obj);"
         ),
         (
             "Include/internal/pycore_time.h",
             "",
             "PyAPI_FUNC(int) _PyTime_FromSecondsObject(PyTime_t *t, PyObject *obj, _PyTime_round_t round);"
         ),
         (
             "Include/internal/pycore_time.h",
             "",
             "PyAPI_FUNC(int) _PyTime_FromMillisecondsObject(PyTime_t *t, PyObject *obj, _PyTime_round_t round);"
         ),
         (
             "Include/internal/pycore_time.h",
             "",
             "PyAPI_FUNC(PyTime_t) _PyTime_AsMilliseconds(PyTime_t t, _PyTime_round_t round);"
         ),
         (
             "Include/internal/pycore_time.h",
             "",
             "PyAPI_FUNC(PyTime_t) _PyTime_AsMicroseconds(PyTime_t t, _PyTime_round_t round);"
         ),
         (
             "Include/internal/pycore_time.h",
             "defined(MS_WINDOWS)",
             "extern PyTime_t _PyTime_As100Nanoseconds(PyTime_t t, _PyTime_round_t round);"
         ),
         (
             "Include/internal/pycore_time.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyTime_AsLong(PyTime_t t);"
         ),
         (
             "Include/internal/pycore_time.h",
             "!defined(MS_WINDOWS)",
             "extern int _PyTime_FromTimeval(PyTime_t *tp, struct timeval *tv);"
         ),
         (
             "Include/internal/pycore_time.h",
             "",
             "PyAPI_FUNC(int) _PyTime_AsTimeval(PyTime_t t, struct timeval *tv, _PyTime_round_t round);"
         ),
         (
             "Include/internal/pycore_time.h",
             "",
             "PyAPI_FUNC(void) _PyTime_AsTimeval_clamp(PyTime_t t, struct timeval *tv, _PyTime_round_t round);"
         ),
         (
             "Include/internal/pycore_time.h",
             "",
             "PyAPI_FUNC(int) _PyTime_AsTimevalTime_t( PyTime_t t, time_t *secs, int *us, _PyTime_round_t round);"
         ),
         (
             "Include/internal/pycore_time.h",
             "(defined(HAVE_CLOCK_GETTIME) || defined(HAVE_KQUEUE))",
             "extern int _PyTime_FromTimespec(PyTime_t *tp, const struct timespec *ts);"
         ),
         (
             "Include/internal/pycore_time.h",
             "(defined(HAVE_CLOCK_GETTIME) || defined(HAVE_KQUEUE))",
             "PyAPI_FUNC(int) _PyTime_AsTimespec(PyTime_t t, struct timespec *ts);"
         ),
         (
             "Include/internal/pycore_time.h",
             "(defined(HAVE_CLOCK_GETTIME) || defined(HAVE_KQUEUE))",
             "PyAPI_FUNC(void) _PyTime_AsTimespec_clamp(PyTime_t t, struct timespec *ts);"
         ),
         (
             "Include/internal/pycore_time.h",
             "",
             "extern PyTime_t _PyTime_Add(PyTime_t t1, PyTime_t t2);"
         ),
         (
             "Include/internal/pycore_time.h",
             "",
             "extern int _PyTime_TimeWithInfo( PyTime_t *t, _Py_clock_info_t *info);"
         ),
         (
             "Include/internal/pycore_time.h",
             "",
             "PyAPI_FUNC(int) _PyTime_MonotonicWithInfo( PyTime_t *t, _Py_clock_info_t *info);"
         ),
         (
             "Include/internal/pycore_time.h",
             "",
             "PyAPI_FUNC(int) _PyTime_localtime(time_t t, struct tm *tm);"
         ),
         (
             "Include/internal/pycore_time.h",
             "",
             "PyAPI_FUNC(int) _PyTime_gmtime(time_t t, struct tm *tm);"
         ),
         (
             "Include/internal/pycore_time.h",
             "",
             "extern int _PyTime_PerfCounterWithInfo( PyTime_t *t, _Py_clock_info_t *info);"
         ),
         (
             "Include/internal/pycore_time.h",
             "",
             "PyAPI_FUNC(PyTime_t) _PyDeadline_Init(PyTime_t timeout);"
         ),
         (
             "Include/internal/pycore_time.h",
             "",
             "PyAPI_FUNC(PyTime_t) _PyDeadline_Get(PyTime_t deadline);"
         ),
         (
             "Include/internal/pycore_time.h",
             "",
             "extern int _PyTimeFraction_Set( _PyTimeFraction *frac, PyTime_t numer, PyTime_t denom);"
         ),
         (
             "Include/internal/pycore_time.h",
             "",
             "extern PyTime_t _PyTimeFraction_Mul( PyTime_t ticks, const _PyTimeFraction *frac);"
         ),
         (
             "Include/internal/pycore_time.h",
             "",
             "extern double _PyTimeFraction_Resolution( const _PyTimeFraction *frac);"
         ),
         (
             "Include/internal/pycore_time.h",
             "",
             "extern PyStatus _PyTime_Init(struct _Py_time_runtime_state *state);"
         ),
         (
             "Include/internal/pycore_token.h",
             "",
             "PyAPI_DATA(const char * const) _PyParser_TokenNames[];"
         ),
         (
             "Include/internal/pycore_token.h",
             "",
             "PyAPI_FUNC(int) _PyToken_OneChar(int);"
         ),
         (
             "Include/internal/pycore_token.h",
             "",
             "PyAPI_FUNC(int) _PyToken_TwoChars(int, int);"
         ),
         (
             "Include/internal/pycore_token.h",
             "",
             "PyAPI_FUNC(int) _PyToken_ThreeChars(int, int, int);"
         ),
         (
             "Include/internal/pycore_traceback.h",
             "",
             "PyAPI_FUNC(int) _Py_DisplaySourceLine(PyObject *, PyObject *, int, int, int *, PyObject **);"
         ),
         (
             "Include/internal/pycore_traceback.h",
             "",
             "PyAPI_FUNC(void) _PyTraceback_Add(const char *, const char *, int);"
         ),
         (
             "Include/internal/pycore_traceback.h",
             "",
             "extern void _Py_DumpTraceback( int fd, PyThreadState *tstate);"
         ),
         (
             "Include/internal/pycore_traceback.h",
             "",
             "extern const char* _Py_DumpTracebackThreads( int fd, PyInterpreterState *interp, PyThreadState *current_tstate);"
         ),
         (
             "Include/internal/pycore_traceback.h",
             "",
             "extern void _Py_DumpASCII(int fd, PyObject *text);"
         ),
         (
             "Include/internal/pycore_traceback.h",
             "",
             "extern void _Py_DumpDecimal( int fd, size_t value);"
         ),
         (
             "Include/internal/pycore_traceback.h",
             "",
             "extern void _Py_DumpHexadecimal( int fd, uintptr_t value, Py_ssize_t width);"
         ),
         (
             "Include/internal/pycore_traceback.h",
             "",
             "extern PyObject* _PyTraceBack_FromFrame( PyObject *tb_next, PyFrameObject *frame);"
         ),
         (
             "Include/internal/pycore_traceback.h",
             "",
             "extern int _PyTraceBack_Print( PyObject *tb, const char *header, PyObject *f);"
         ),
         (
             "Include/internal/pycore_traceback.h",
             "",
             "extern int _Py_WriteIndentedMargin(int, const char*, PyObject *);"
         ),
         (
             "Include/internal/pycore_traceback.h",
             "",
             "extern int _Py_WriteIndent(int, PyObject *);"
         ),
         (
             "Include/internal/pycore_traceback.h",
             "",
             "PyAPI_FUNC(void) _Py_InitDumpStack(void);"
         ),
         (
             "Include/internal/pycore_traceback.h",
             "",
             "PyAPI_FUNC(void) _Py_DumpStack(int fd);"
         ),
         (
             "Include/internal/pycore_traceback.h",
             "",
             "extern void _Py_DumpTraceback_Init(void);"
         ),
         (
             "Include/internal/pycore_tracemalloc.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyTraceMalloc_GetTraceback( unsigned int domain, uintptr_t ptr);"
         ),
         (
             "Include/internal/pycore_tracemalloc.h",
             "",
             "extern int _PyTraceMalloc_IsTracing(void);"
         ),
         (
             "Include/internal/pycore_tracemalloc.h",
             "",
             "extern void _PyTraceMalloc_ClearTraces(void);"
         ),
         (
             "Include/internal/pycore_tracemalloc.h",
             "",
             "extern PyObject* _PyTraceMalloc_GetTraces(void);"
         ),
         (
             "Include/internal/pycore_tracemalloc.h",
             "",
             "extern PyObject* _PyTraceMalloc_GetObjectTraceback(PyObject *obj);"
         ),
         (
             "Include/internal/pycore_tracemalloc.h",
             "",
             "extern PyStatus _PyTraceMalloc_Init(void);"
         ),
         (
             "Include/internal/pycore_tracemalloc.h",
             "",
             "extern int _PyTraceMalloc_Start(int max_nframe);"
         ),
         (
             "Include/internal/pycore_tracemalloc.h",
             "",
             "extern void _PyTraceMalloc_Stop(void);"
         ),
         (
             "Include/internal/pycore_tracemalloc.h",
             "",
             "extern int _PyTraceMalloc_GetTracebackLimit(void);"
         ),
         (
             "Include/internal/pycore_tracemalloc.h",
             "",
             "extern size_t _PyTraceMalloc_GetMemory(void);"
         ),
         (
             "Include/internal/pycore_tracemalloc.h",
             "",
             "extern PyObject* _PyTraceMalloc_GetTracedMemory(void);"
         ),
         (
             "Include/internal/pycore_tracemalloc.h",
             "",
             "extern void _PyTraceMalloc_ResetPeak(void);"
         ),
         (
             "Include/internal/pycore_tuple.h",
             "",
             "extern void _PyTuple_MaybeUntrack(PyObject *);"
         ),
         (
             "Include/internal/pycore_tuple.h",
             "",
             "extern void _PyTuple_DebugMallocStats(FILE *out);"
         ),
         (
             "Include/internal/pycore_tuple.h",
             "",
             "extern PyStatus _PyTuple_InitGlobalObjects(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_tuple.h",
             "",
             "PyAPI_FUNC(PyObject *)_PyTuple_FromArray(PyObject *const *, Py_ssize_t);"
         ),
         (
             "Include/internal/pycore_tuple.h",
             "",
             "PyAPI_FUNC(PyObject *)_PyTuple_FromStackRefStealOnSuccess(const union _PyStackRef *, Py_ssize_t);"
         ),
         (
             "Include/internal/pycore_tuple.h",
             "",
             "PyAPI_FUNC(PyObject *)_PyTuple_FromArraySteal(PyObject *const *, Py_ssize_t);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "extern PyStatus _PyTypes_InitTypes(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "extern void _PyTypes_FiniTypes(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "extern void _PyTypes_FiniExtTypes(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "extern void _PyTypes_Fini(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "extern void _PyTypes_AfterFork(void);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "extern int _PyStaticType_InitBuiltin( PyInterpreterState *interp, PyTypeObject *type);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "extern void _PyStaticType_FiniBuiltin( PyInterpreterState *interp, PyTypeObject *type);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "extern void _PyStaticType_ClearWeakRefs( PyInterpreterState *interp, PyTypeObject *type);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "extern managed_static_type_state * _PyStaticType_GetState( PyInterpreterState *interp, PyTypeObject *type);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "PyAPI_FUNC(int) _PyStaticType_InitForExtension( PyInterpreterState *interp, PyTypeObject *self);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyStaticType_GetBuiltins(void);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyType_GetDict(PyTypeObject *);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "extern PyObject * _PyType_GetBases(PyTypeObject *type);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "extern PyObject * _PyType_GetMRO(PyTypeObject *type);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "extern PyObject* _PyType_GetSubclasses(PyTypeObject *);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "extern int _PyType_HasSubclasses(PyTypeObject *);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyType_GetSlotWrapperNames(void);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "extern PyObject* _Py_type_getattro_impl(PyTypeObject *type, PyObject *name, int *suppress_missing_attribute);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "extern PyObject* _Py_type_getattro(PyObject *type, PyObject *name);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "extern PyObject* _Py_BaseObject_RichCompare(PyObject* self, PyObject* other, int op);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "extern PyObject* _Py_slot_tp_getattro(PyObject *self, PyObject *name);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "extern PyObject* _Py_slot_tp_getattr_hook(PyObject *self, PyObject *name);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "extern PyTypeObject _PyBufferWrapper_Type;"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) _PySuper_Lookup(PyTypeObject *su_type, PyObject *su_obj, PyObject *name, int *meth_found);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "extern PyObject* _PyType_GetFullyQualifiedName(PyTypeObject *type, char sep);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "extern void _PyType_SetFlags(PyTypeObject *self, unsigned long mask, unsigned long flags);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "extern int _PyType_AddMethod(PyTypeObject *, PyMethodDef *);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "extern void _PyType_SetFlagsRecursive(PyTypeObject *self, unsigned long mask, unsigned long flags);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "extern unsigned int _PyType_GetVersionForCurrentState(PyTypeObject *tp);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "PyAPI_FUNC(void) _PyType_SetVersion(PyTypeObject *tp, unsigned int version);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "extern int _PyType_Validate(PyTypeObject *ty, _py_validate_type validate, unsigned int *tp_version);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "extern int _PyType_CacheGetItemForSpecialization(PyHeapTypeObject *ht, PyObject *descriptor, uint32_t tp_version);"
         ),
         (
             "Include/internal/pycore_typeobject.h",
             "",
             "PyAPI_FUNC(int) _PyType_GetBaseByToken_Borrow(PyTypeObject *type, void *token, PyTypeObject **result);"
         ),
         (
             "Include/internal/pycore_typevarobject.h",
             "",
             "extern PyObject *_Py_make_typevar(PyObject *, PyObject *, PyObject *);"
         ),
         (
             "Include/internal/pycore_typevarobject.h",
             "",
             "extern PyObject *_Py_make_paramspec(PyThreadState *, PyObject *);"
         ),
         (
             "Include/internal/pycore_typevarobject.h",
             "",
             "extern PyObject *_Py_make_typevartuple(PyThreadState *, PyObject *);"
         ),
         (
             "Include/internal/pycore_typevarobject.h",
             "",
             "extern PyObject *_Py_make_typealias(PyThreadState *, PyObject *);"
         ),
         (
             "Include/internal/pycore_typevarobject.h",
             "",
             "extern PyObject *_Py_subscript_generic(PyThreadState *, PyObject *);"
         ),
         (
             "Include/internal/pycore_typevarobject.h",
             "",
             "extern PyObject *_Py_set_typeparam_default(PyThreadState *, PyObject *, PyObject *);"
         ),
         (
             "Include/internal/pycore_typevarobject.h",
             "",
             "extern int _Py_initialize_generic(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_typevarobject.h",
             "",
             "extern void _Py_clear_generic_types(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_typevarobject.h",
             "",
             "extern int _Py_typing_type_repr(PyUnicodeWriter *, PyObject *);"
         ),
         (
             "Include/internal/pycore_typevarobject.h",
             "",
             "extern PyTypeObject _PyTypeAlias_Type;"
         ),
         (
             "Include/internal/pycore_typevarobject.h",
             "",
             "extern PyTypeObject _PyNoDefault_Type;"
         ),
         (
             "Include/internal/pycore_typevarobject.h",
             "",
             "extern PyObject _Py_NoDefaultStruct;"
         ),
         (
             "Include/internal/pycore_ucnhash.h",
             "",
             "extern _PyUnicode_Name_CAPI* _PyUnicode_GetNameCAPI(void);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern int _PyUnicode_IsXidStart(Py_UCS4 ch);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern int _PyUnicode_IsXidContinue(Py_UCS4 ch);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern int _PyUnicode_ToLowerFull(Py_UCS4 ch, Py_UCS4 *res);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern int _PyUnicode_ToTitleFull(Py_UCS4 ch, Py_UCS4 *res);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern int _PyUnicode_ToUpperFull(Py_UCS4 ch, Py_UCS4 *res);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern int _PyUnicode_ToFoldedFull(Py_UCS4 ch, Py_UCS4 *res);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern int _PyUnicode_IsCaseIgnorable(Py_UCS4 ch);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern int _PyUnicode_IsCased(Py_UCS4 ch);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "PyAPI_FUNC(int) _PyUnicode_CheckConsistency( PyObject *op, int check_content);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "PyAPI_FUNC(void) _PyUnicode_ExactDealloc(PyObject *op);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern Py_ssize_t _PyUnicode_InternedSize(void);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern Py_ssize_t _PyUnicode_InternedSize_Immortal(void);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyUnicode_Copy( PyObject *unicode);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern void _PyUnicode_FastFill( PyObject *unicode, Py_ssize_t start, Py_ssize_t length, Py_UCS4 fill_char );"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern void _PyUnicode_FastCopyCharacters( PyObject *to, Py_ssize_t to_start, PyObject *from, Py_ssize_t from_start, Py_ssize_t how_many );"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern PyObject* _PyUnicode_FromASCII( const char *buffer, Py_ssize_t size);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern Py_UCS4 _PyUnicode_FindMaxChar ( PyObject *unicode, Py_ssize_t start, Py_ssize_t end);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern int _PyUnicode_FormatAdvancedWriter( _PyUnicodeWriter *writer, PyObject *obj, PyObject *format_spec, Py_ssize_t start, Py_ssize_t end);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern PyObject* _PyUnicode_EncodeUTF7( PyObject *unicode, int base64SetO, int base64WhiteSpace, const char *errors);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyUnicode_AsUTF8String( PyObject *unicode, const char *errors);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyUnicode_EncodeUTF32( PyObject *object, const char *errors, int byteorder);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyUnicode_EncodeUTF16( PyObject* unicode, const char *errors, int byteorder);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern PyObject* _PyUnicode_DecodeUnicodeEscapeStateful( const char *string, Py_ssize_t length, const char *errors, Py_ssize_t *consumed);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyUnicode_DecodeUnicodeEscapeInternal2( const char *string, Py_ssize_t length, const char *errors, Py_ssize_t *consumed, int *first_invalid_escape_char, const char **first_invalid_escape_ptr);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern PyObject* _PyUnicode_DecodeRawUnicodeEscapeStateful( const char *string, Py_ssize_t length, const char *errors, Py_ssize_t *consumed);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern PyObject* _PyUnicode_AsLatin1String( PyObject* unicode, const char* errors);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern PyObject* _PyUnicode_AsASCIIString( PyObject* unicode, const char* errors);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern PyObject* _PyUnicode_EncodeCharmap( PyObject *unicode, PyObject *mapping, const char *errors);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyUnicode_TransformDecimalAndSpaceToASCII( PyObject *unicode);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) _PyUnicode_JoinArray( PyObject *separator, PyObject *const *items, Py_ssize_t seqlen );"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern int _PyUnicode_EqualToASCIIId( PyObject *left, _Py_Identifier *right );"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "PyAPI_FUNC(int) _PyUnicode_EqualToASCIIString( PyObject *left, const char *right );"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern PyObject* _PyUnicode_XStrip( PyObject *self, int striptype, PyObject *sepobj );"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern Py_ssize_t _PyUnicode_InsertThousandsGrouping( _PyUnicodeWriter *writer, Py_ssize_t n_buffer, PyObject *digits, Py_ssize_t d_pos, Py_ssize_t n_digits, Py_ssize_t min_width, const char *grouping, PyObject *thousands_sep, Py_UCS4 *maxchar, int forward);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern PyObject* _PyUnicode_Dedent(PyObject *unicode);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern PyObject* _PyUnicode_FormatLong(PyObject *, int, int, int);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "PyAPI_FUNC(int) _PyUnicode_Equal(PyObject *, PyObject *);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern int _PyUnicode_WideCharString_Converter(PyObject *, void *);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern int _PyUnicode_WideCharString_Opt_Converter(PyObject *, void *);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) _PyUnicode_ScanIdentifier(PyObject *);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern void _PyUnicode_InitState(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern PyStatus _PyUnicode_InitGlobalObjects(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern PyStatus _PyUnicode_InitTypes(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern void _PyUnicode_Fini(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern void _PyUnicode_FiniTypes(PyInterpreterState *);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern PyTypeObject _PyUnicodeASCIIIter_Type;"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "PyAPI_FUNC(void) _PyUnicode_InternMortal(PyInterpreterState *interp, PyObject **);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "PyAPI_FUNC(void) _PyUnicode_InternImmortal(PyInterpreterState *interp, PyObject **);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "PyAPI_FUNC(void) _PyUnicode_InternInPlace(PyInterpreterState *interp, PyObject **p);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern void _PyUnicode_InternStatic(PyInterpreterState *interp, PyObject **);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "extern void _PyUnicode_ClearInterned(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_unicodeobject.h",
             "",
             "PyAPI_FUNC(const char *) _PyUnicode_AsUTF8NoNUL(PyObject *);"
         ),
         (
             "Include/internal/pycore_unionobject.h",
             "",
             "PyAPI_DATA(PyTypeObject) _PyUnion_Type;"
         ),
         (
             "Include/internal/pycore_unionobject.h",
             "",
             "PyAPI_FUNC(PyObject *) _Py_union_type_or(PyObject *, PyObject *);"
         ),
         (
             "Include/internal/pycore_unionobject.h",
             "",
             "extern PyObject *_Py_subs_parameters(PyObject *, PyObject *, PyObject *, PyObject *);"
         ),
         (
             "Include/internal/pycore_unionobject.h",
             "",
             "extern PyObject *_Py_make_parameters(PyObject *);"
         ),
         (
             "Include/internal/pycore_unionobject.h",
             "",
             "extern PyObject *_Py_union_args(PyObject *self);"
         ),
         (
             "Include/internal/pycore_unionobject.h",
             "",
             "extern PyObject *_Py_union_from_tuple(PyObject *args);"
         ),
         (
             "Include/internal/pycore_uniqueid.h",
             "defined(Py_GIL_DISABLED)",
             "extern Py_ssize_t _PyObject_AssignUniqueId(PyObject *obj);"
         ),
         (
             "Include/internal/pycore_uniqueid.h",
             "defined(Py_GIL_DISABLED)",
             "extern void _PyObject_ReleaseUniqueId(Py_ssize_t unique_id);"
         ),
         (
             "Include/internal/pycore_uniqueid.h",
             "defined(Py_GIL_DISABLED)",
             "extern void _PyObject_DisablePerThreadRefcounting(PyObject *obj);"
         ),
         (
             "Include/internal/pycore_uniqueid.h",
             "defined(Py_GIL_DISABLED)",
             "extern void _PyObject_MergePerThreadRefcounts(_PyThreadStateImpl *tstate);"
         ),
         (
             "Include/internal/pycore_uniqueid.h",
             "defined(Py_GIL_DISABLED)",
             "extern void _PyObject_FinalizePerThreadRefcounts(_PyThreadStateImpl *tstate);"
         ),
         (
             "Include/internal/pycore_uniqueid.h",
             "defined(Py_GIL_DISABLED)",
             "extern void _PyObject_FinalizeUniqueIdPool(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_uniqueid.h",
             "defined(Py_GIL_DISABLED)",
             "PyAPI_FUNC(void) _PyObject_ThreadIncrefSlow(PyObject *obj, size_t idx);"
         ),
         (
             "Include/internal/pycore_uop_metadata.h",
             "",
             "extern int _PyUop_num_popped(int opcode, int oparg);"
         ),
         (
             "Include/internal/pycore_warnings.h",
             "",
             "extern int _PyWarnings_InitState(PyInterpreterState *interp);"
         ),
         (
             "Include/internal/pycore_warnings.h",
             "",
             "extern PyObject* _PyWarnings_Init(void);"
         ),
         (
             "Include/internal/pycore_warnings.h",
             "",
             "extern void _PyErr_WarnUnawaitedCoroutine(PyObject *coro);"
         ),
         (
             "Include/internal/pycore_warnings.h",
             "",
             "extern void _PyErr_WarnUnawaitedAgenMethod(PyAsyncGenObject *agen, PyObject *method);"
         ),
         (
             "Include/internal/pycore_weakref.h",
             "",
             "extern Py_ssize_t _PyWeakref_GetWeakrefCount(PyObject *obj);"
         ),
         (
             "Include/internal/pycore_weakref.h",
             "",
             "extern void _PyWeakref_ClearWeakRefsNoCallbacks(PyObject *obj);"
         ),
         (
             "Include/internal/pycore_weakref.h",
             "",
             "PyAPI_FUNC(int) _PyWeakref_IsDead(PyObject *weakref);"
         ),
         ("Include/intrcheck.h", "", "PyAPI_FUNC(int) PyOS_InterruptOccurred(void);"),
         (
             "Include/intrcheck.h",
             "defined(HAVE_FORK) && (!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03070000)",
             "PyAPI_FUNC(void) PyOS_BeforeFork(void);"
         ),
         (
             "Include/intrcheck.h",
             "defined(HAVE_FORK) && (!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03070000)",
             "PyAPI_FUNC(void) PyOS_AfterFork_Parent(void);"
         ),
         (
             "Include/intrcheck.h",
             "defined(HAVE_FORK) && (!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03070000)",
             "PyAPI_FUNC(void) PyOS_AfterFork_Child(void);"
         ),
         (
             "Include/intrcheck.h",
             "",
             "Py_DEPRECATED(3.7) PyAPI_FUNC(void) PyOS_AfterFork(void);"
         ),
         ("Include/iterobject.h", "", "PyAPI_DATA(PyTypeObject) PySeqIter_Type;"),
         ("Include/iterobject.h", "", "PyAPI_DATA(PyTypeObject) PyCallIter_Type;"),
         (
             "Include/iterobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PySeqIter_New(PyObject *);"
         ),
         (
             "Include/iterobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyCallIter_New(PyObject *, PyObject *);"
         ),
         ("Include/listobject.h", "", "PyAPI_DATA(PyTypeObject) PyList_Type;"),
         ("Include/listobject.h", "", "PyAPI_DATA(PyTypeObject) PyListIter_Type;"),
         ("Include/listobject.h", "", "PyAPI_DATA(PyTypeObject) PyListRevIter_Type;"),
         (
             "Include/listobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyList_New(Py_ssize_t size);"
         ),
         (
             "Include/listobject.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) PyList_Size(PyObject *);"
         ),
         (
             "Include/listobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyList_GetItem(PyObject *, Py_ssize_t);"
         ),
         (
             "Include/listobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030d0000)",
             "PyAPI_FUNC(PyObject *) PyList_GetItemRef(PyObject *, Py_ssize_t);"
         ),
         (
             "Include/listobject.h",
             "",
             "PyAPI_FUNC(int) PyList_SetItem(PyObject *, Py_ssize_t, PyObject *);"
         ),
         (
             "Include/listobject.h",
             "",
             "PyAPI_FUNC(int) PyList_Insert(PyObject *, Py_ssize_t, PyObject *);"
         ),
         (
             "Include/listobject.h",
             "",
             "PyAPI_FUNC(int) PyList_Append(PyObject *, PyObject *);"
         ),
         (
             "Include/listobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyList_GetSlice(PyObject *, Py_ssize_t, Py_ssize_t);"
         ),
         (
             "Include/listobject.h",
             "",
             "PyAPI_FUNC(int) PyList_SetSlice(PyObject *, Py_ssize_t, Py_ssize_t, PyObject *);"
         ),
         ("Include/listobject.h", "", "PyAPI_FUNC(int) PyList_Sort(PyObject *);"),
         ("Include/listobject.h", "", "PyAPI_FUNC(int) PyList_Reverse(PyObject *);"),
         (
             "Include/listobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyList_AsTuple(PyObject *);"
         ),
         ("Include/longobject.h", "", "PyAPI_FUNC(PyObject *) PyLong_FromLong(long);"),
         (
             "Include/longobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyLong_FromUnsignedLong(unsigned long);"
         ),
         (
             "Include/longobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyLong_FromSize_t(size_t);"
         ),
         (
             "Include/longobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyLong_FromSsize_t(Py_ssize_t);"
         ),
         (
             "Include/longobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyLong_FromDouble(double);"
         ),
         ("Include/longobject.h", "", "PyAPI_FUNC(long) PyLong_AsLong(PyObject *);"),
         (
             "Include/longobject.h",
             "",
             "PyAPI_FUNC(long) PyLong_AsLongAndOverflow(PyObject *, int *);"
         ),
         (
             "Include/longobject.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) PyLong_AsSsize_t(PyObject *);"
         ),
         (
             "Include/longobject.h",
             "",
             "PyAPI_FUNC(size_t) PyLong_AsSize_t(PyObject *);"
         ),
         (
             "Include/longobject.h",
             "",
             "PyAPI_FUNC(unsigned long) PyLong_AsUnsignedLong(PyObject *);"
         ),
         (
             "Include/longobject.h",
             "",
             "PyAPI_FUNC(unsigned long) PyLong_AsUnsignedLongMask(PyObject *);"
         ),
         (
             "Include/longobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030d0000)",
             "PyAPI_FUNC(int) PyLong_AsInt(PyObject *);"
         ),
         (
             "Include/longobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030e0000)",
             "PyAPI_FUNC(PyObject*) PyLong_FromInt32(int32_t value);"
         ),
         (
             "Include/longobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030e0000)",
             "PyAPI_FUNC(PyObject*) PyLong_FromUInt32(uint32_t value);"
         ),
         (
             "Include/longobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030e0000)",
             "PyAPI_FUNC(PyObject*) PyLong_FromInt64(int64_t value);"
         ),
         (
             "Include/longobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030e0000)",
             "PyAPI_FUNC(PyObject*) PyLong_FromUInt64(uint64_t value);"
         ),
         (
             "Include/longobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030e0000)",
             "PyAPI_FUNC(int) PyLong_AsInt32(PyObject *obj, int32_t *value);"
         ),
         (
             "Include/longobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030e0000)",
             "PyAPI_FUNC(int) PyLong_AsUInt32(PyObject *obj, uint32_t *value);"
         ),
         (
             "Include/longobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030e0000)",
             "PyAPI_FUNC(int) PyLong_AsInt64(PyObject *obj, int64_t *value);"
         ),
         (
             "Include/longobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030e0000)",
             "PyAPI_FUNC(int) PyLong_AsUInt64(PyObject *obj, uint64_t *value);"
         ),
         (
             "Include/longobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030e0000)",
             "PyAPI_FUNC(Py_ssize_t) PyLong_AsNativeBytes(PyObject* v, void* buffer, Py_ssize_t n_bytes, int flags);"
         ),
         (
             "Include/longobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030e0000)",
             "PyAPI_FUNC(PyObject*) PyLong_FromNativeBytes(const void* buffer, size_t n_bytes, int flags);"
         ),
         (
             "Include/longobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030e0000)",
             "PyAPI_FUNC(PyObject*) PyLong_FromUnsignedNativeBytes(const void* buffer, size_t n_bytes, int flags);"
         ),
         ("Include/longobject.h", "", "PyAPI_FUNC(PyObject *) PyLong_GetInfo(void);"),
         (
             "Include/longobject.h",
             "",
             "PyAPI_FUNC(double) PyLong_AsDouble(PyObject *);"
         ),
         (
             "Include/longobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyLong_FromVoidPtr(void *);"
         ),
         (
             "Include/longobject.h",
             "",
             "PyAPI_FUNC(void *) PyLong_AsVoidPtr(PyObject *);"
         ),
         (
             "Include/longobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyLong_FromLongLong(long long);"
         ),
         (
             "Include/longobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyLong_FromUnsignedLongLong(unsigned long long);"
         ),
         (
             "Include/longobject.h",
             "",
             "PyAPI_FUNC(long long) PyLong_AsLongLong(PyObject *);"
         ),
         (
             "Include/longobject.h",
             "",
             "PyAPI_FUNC(unsigned long long) PyLong_AsUnsignedLongLong(PyObject *);"
         ),
         (
             "Include/longobject.h",
             "",
             "PyAPI_FUNC(unsigned long long) PyLong_AsUnsignedLongLongMask(PyObject *);"
         ),
         (
             "Include/longobject.h",
             "",
             "PyAPI_FUNC(long long) PyLong_AsLongLongAndOverflow(PyObject *, int *);"
         ),
         (
             "Include/longobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyLong_FromString(const char *, char **, int);"
         ),
         (
             "Include/longobject.h",
             "",
             "PyAPI_FUNC(unsigned long) PyOS_strtoul(const char *, char **, int);"
         ),
         (
             "Include/longobject.h",
             "",
             "PyAPI_FUNC(long) PyOS_strtol(const char *, char **, int);"
         ),
         (
             "Include/marshal.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyMarshal_ReadObjectFromString(const char *, Py_ssize_t);"
         ),
         (
             "Include/marshal.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyMarshal_WriteObjectToString(PyObject *, int);"
         ),
         (
             "Include/marshal.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(long) PyMarshal_ReadLongFromFile(FILE *);"
         ),
         (
             "Include/marshal.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyMarshal_ReadShortFromFile(FILE *);"
         ),
         (
             "Include/marshal.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyMarshal_ReadObjectFromFile(FILE *);"
         ),
         (
             "Include/marshal.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) PyMarshal_ReadLastObjectFromFile(FILE *);"
         ),
         (
             "Include/marshal.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(void) PyMarshal_WriteLongToFile(long, FILE *, int);"
         ),
         (
             "Include/marshal.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(void) PyMarshal_WriteObjectToFile(PyObject *, FILE *, int);"
         ),
         ("Include/memoryobject.h", "", "PyAPI_DATA(PyTypeObject) PyMemoryView_Type;"),
         (
             "Include/memoryobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyMemoryView_FromObject(PyObject *base);"
         ),
         (
             "Include/memoryobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_FUNC(PyObject *) PyMemoryView_FromMemory(char *mem, Py_ssize_t size, int flags);"
         ),
         (
             "Include/memoryobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030b0000)",
             "PyAPI_FUNC(PyObject *) PyMemoryView_FromBuffer(const Py_buffer *info);"
         ),
         (
             "Include/memoryobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyMemoryView_GetContiguous(PyObject *base, int buffertype, char order);"
         ),
         ("Include/methodobject.h", "", "PyAPI_DATA(PyTypeObject) PyCFunction_Type;"),
         (
             "Include/methodobject.h",
             "",
             "PyAPI_FUNC(PyCFunction) PyCFunction_GetFunction(PyObject *);"
         ),
         (
             "Include/methodobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyCFunction_GetSelf(PyObject *);"
         ),
         (
             "Include/methodobject.h",
             "",
             "PyAPI_FUNC(int) PyCFunction_GetFlags(PyObject *);"
         ),
         (
             "Include/methodobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyCFunction_New(PyMethodDef *, PyObject *);"
         ),
         (
             "Include/methodobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyCFunction_NewEx(PyMethodDef *, PyObject *, PyObject *);"
         ),
         (
             "Include/methodobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03090000)",
             "PyAPI_FUNC(PyObject *) PyCMethod_New(PyMethodDef *, PyObject *, PyObject *, PyTypeObject *);"
         ),
         (
             "Include/modsupport.h",
             "",
             "PyAPI_FUNC(int) PyArg_Parse(PyObject *, const char *, ...);"
         ),
         (
             "Include/modsupport.h",
             "",
             "PyAPI_FUNC(int) PyArg_ParseTuple(PyObject *, const char *, ...);"
         ),
         (
             "Include/modsupport.h",
             "",
             "PyAPI_FUNC(int) PyArg_ParseTupleAndKeywords(PyObject *, PyObject *, const char *, PY_CXX_CONST char * const *, ...);"
         ),
         (
             "Include/modsupport.h",
             "",
             "PyAPI_FUNC(int) PyArg_VaParse(PyObject *, const char *, va_list);"
         ),
         (
             "Include/modsupport.h",
             "",
             "PyAPI_FUNC(int) PyArg_VaParseTupleAndKeywords(PyObject *, PyObject *, const char *, PY_CXX_CONST char * const *, va_list);"
         ),
         (
             "Include/modsupport.h",
             "",
             "PyAPI_FUNC(int) PyArg_ValidateKeywordArguments(PyObject *);"
         ),
         (
             "Include/modsupport.h",
             "",
             "PyAPI_FUNC(int) PyArg_UnpackTuple(PyObject *, const char *, Py_ssize_t, Py_ssize_t, ...);"
         ),
         (
             "Include/modsupport.h",
             "",
             "PyAPI_FUNC(PyObject *) Py_BuildValue(const char *, ...);"
         ),
         (
             "Include/modsupport.h",
             "",
             "PyAPI_FUNC(PyObject *) Py_VaBuildValue(const char *, va_list);"
         ),
         (
             "Include/modsupport.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030a0000)",
             "PyAPI_FUNC(int) PyModule_AddObjectRef(PyObject *mod, const char *name, PyObject *value);"
         ),
         (
             "Include/modsupport.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030d0000)",
             "PyAPI_FUNC(int) PyModule_Add(PyObject *mod, const char *name, PyObject *value);"
         ),
         (
             "Include/modsupport.h",
             "",
             "PyAPI_FUNC(int) PyModule_AddObject(PyObject *mod, const char *, PyObject *value);"
         ),
         (
             "Include/modsupport.h",
             "",
             "PyAPI_FUNC(int) PyModule_AddIntConstant(PyObject *, const char *, long);"
         ),
         (
             "Include/modsupport.h",
             "",
             "PyAPI_FUNC(int) PyModule_AddStringConstant(PyObject *, const char *, const char *);"
         ),
         (
             "Include/modsupport.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03090000)",
             "PyAPI_FUNC(int) PyModule_AddType(PyObject *module, PyTypeObject *type);"
         ),
         (
             "Include/modsupport.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03050000)",
             "PyAPI_FUNC(int) PyModule_SetDocString(PyObject *, const char *);"
         ),
         (
             "Include/modsupport.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03050000)",
             "PyAPI_FUNC(int) PyModule_AddFunctions(PyObject *, PyMethodDef *);"
         ),
         (
             "Include/modsupport.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03050000)",
             "PyAPI_FUNC(int) PyModule_ExecDef(PyObject *module, PyModuleDef *def);"
         ),
         (
             "Include/modsupport.h",
             "",
             "PyAPI_FUNC(PyObject *) PyModule_Create2(PyModuleDef*, int apiver);"
         ),
         (
             "Include/modsupport.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03050000)",
             "PyAPI_FUNC(PyObject *) PyModule_FromDefAndSpec2(PyModuleDef *def, PyObject *spec, int module_api_version);"
         ),
         ("Include/moduleobject.h", "", "PyAPI_DATA(PyTypeObject) PyModule_Type;"),
         (
             "Include/moduleobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_FUNC(PyObject *) PyModule_NewObject( PyObject *name );"
         ),
         (
             "Include/moduleobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyModule_New( const char *name );"
         ),
         (
             "Include/moduleobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyModule_GetDict(PyObject *);"
         ),
         (
             "Include/moduleobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_FUNC(PyObject *) PyModule_GetNameObject(PyObject *);"
         ),
         (
             "Include/moduleobject.h",
             "",
             "PyAPI_FUNC(const char *) PyModule_GetName(PyObject *);"
         ),
         (
             "Include/moduleobject.h",
             "",
             "Py_DEPRECATED(3.2) PyAPI_FUNC(const char *) PyModule_GetFilename(PyObject *);"
         ),
         (
             "Include/moduleobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyModule_GetFilenameObject(PyObject *);"
         ),
         (
             "Include/moduleobject.h",
             "",
             "PyAPI_FUNC(PyModuleDef*) PyModule_GetDef(PyObject*);"
         ),
         (
             "Include/moduleobject.h",
             "",
             "PyAPI_FUNC(void*) PyModule_GetState(PyObject*);"
         ),
         (
             "Include/moduleobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03050000)",
             "PyAPI_FUNC(PyObject *) PyModuleDef_Init(PyModuleDef*);"
         ),
         (
             "Include/moduleobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03050000)",
             "PyAPI_DATA(PyTypeObject) PyModuleDef_Type;"
         ),
         (
             "Include/moduleobject.h",
             "(!defined(Py_LIMITED_API) && defined(Py_GIL_DISABLED))",
             "PyAPI_FUNC(int) PyUnstable_Module_SetGIL(PyObject *module, void *gil);"
         ),
         ("Include/object.h", "", "PyAPI_FUNC(int) Py_Is(PyObject *x, PyObject *y);"),
         (
             "Include/object.h",
             "(defined(Py_GIL_DISABLED) && !defined(Py_LIMITED_API))",
             "PyAPI_FUNC(uintptr_t) _Py_GetThreadLocal_Addr(void);"
         ),
         ("Include/object.h", "", "PyAPI_FUNC(PyTypeObject*) Py_TYPE(PyObject *ob);"),
         ("Include/object.h", "", "PyAPI_DATA(PyTypeObject) PyLong_Type;"),
         ("Include/object.h", "", "PyAPI_DATA(PyTypeObject) PyBool_Type;"),
         (
             "Include/object.h",
             "",
             "PyAPI_FUNC(PyObject*) PyType_FromSpec(PyType_Spec*);"
         ),
         (
             "Include/object.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_FUNC(PyObject*) PyType_FromSpecWithBases(PyType_Spec*, PyObject*);"
         ),
         (
             "Include/object.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03040000)",
             "PyAPI_FUNC(void*) PyType_GetSlot(PyTypeObject*, int);"
         ),
         (
             "Include/object.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03090000)",
             "PyAPI_FUNC(PyObject*) PyType_FromModuleAndSpec(PyObject *, PyType_Spec *, PyObject *);"
         ),
         (
             "Include/object.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03090000)",
             "PyAPI_FUNC(PyObject *) PyType_GetModule(PyTypeObject *);"
         ),
         (
             "Include/object.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03090000)",
             "PyAPI_FUNC(void *) PyType_GetModuleState(PyTypeObject *);"
         ),
         (
             "Include/object.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030B0000)",
             "PyAPI_FUNC(PyObject *) PyType_GetName(PyTypeObject *);"
         ),
         (
             "Include/object.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030B0000)",
             "PyAPI_FUNC(PyObject *) PyType_GetQualName(PyTypeObject *);"
         ),
         (
             "Include/object.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030D0000)",
             "PyAPI_FUNC(PyObject *) PyType_GetFullyQualifiedName(PyTypeObject *type);"
         ),
         (
             "Include/object.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030D0000)",
             "PyAPI_FUNC(PyObject *) PyType_GetModuleName(PyTypeObject *type);"
         ),
         (
             "Include/object.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030C0000)",
             "PyAPI_FUNC(PyObject *) PyType_FromMetaclass(PyTypeObject*, PyObject*, PyType_Spec*, PyObject*);"
         ),
         (
             "Include/object.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030C0000)",
             "PyAPI_FUNC(void *) PyObject_GetTypeData(PyObject *obj, PyTypeObject *cls);"
         ),
         (
             "Include/object.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030C0000)",
             "PyAPI_FUNC(Py_ssize_t) PyType_GetTypeDataSize(PyTypeObject *cls);"
         ),
         (
             "Include/object.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030E0000)",
             "PyAPI_FUNC(int) PyType_GetBaseByToken(PyTypeObject *, void *, PyTypeObject **);"
         ),
         (
             "Include/object.h",
             "",
             "PyAPI_FUNC(int) PyType_IsSubtype(PyTypeObject *, PyTypeObject *);"
         ),
         ("Include/object.h", "", "PyAPI_DATA(PyTypeObject) PyType_Type;"),
         ("Include/object.h", "", "PyAPI_DATA(PyTypeObject) PyBaseObject_Type;"),
         ("Include/object.h", "", "PyAPI_DATA(PyTypeObject) PySuper_Type;"),
         (
             "Include/object.h",
             "",
             "PyAPI_FUNC(unsigned long) PyType_GetFlags(PyTypeObject*);"
         ),
         ("Include/object.h", "", "PyAPI_FUNC(int) PyType_Ready(PyTypeObject *);"),
         (
             "Include/object.h",
             "",
             "PyAPI_FUNC(PyObject *) PyType_GenericAlloc(PyTypeObject *, Py_ssize_t);"
         ),
         (
             "Include/object.h",
             "",
             "PyAPI_FUNC(PyObject *) PyType_GenericNew(PyTypeObject *, PyObject *, PyObject *);"
         ),
         ("Include/object.h", "", "PyAPI_FUNC(unsigned int) PyType_ClearCache(void);"),
         ("Include/object.h", "", "PyAPI_FUNC(void) PyType_Modified(PyTypeObject *);"),
         ("Include/object.h", "", "PyAPI_FUNC(PyObject *) PyObject_Repr(PyObject *);"),
         ("Include/object.h", "", "PyAPI_FUNC(PyObject *) PyObject_Str(PyObject *);"),
         ("Include/object.h", "", "PyAPI_FUNC(PyObject *) PyObject_ASCII(PyObject *);"),
         ("Include/object.h", "", "PyAPI_FUNC(PyObject *) PyObject_Bytes(PyObject *);"),
         (
             "Include/object.h",
             "",
             "PyAPI_FUNC(PyObject *) PyObject_RichCompare(PyObject *, PyObject *, int);"
         ),
         (
             "Include/object.h",
             "",
             "PyAPI_FUNC(int) PyObject_RichCompareBool(PyObject *, PyObject *, int);"
         ),
         (
             "Include/object.h",
             "",
             "PyAPI_FUNC(PyObject *) PyObject_GetAttrString(PyObject *, const char *);"
         ),
         (
             "Include/object.h",
             "",
             "PyAPI_FUNC(int) PyObject_SetAttrString(PyObject *, const char *, PyObject *);"
         ),
         (
             "Include/object.h",
             "",
             "PyAPI_FUNC(int) PyObject_DelAttrString(PyObject *v, const char *name);"
         ),
         (
             "Include/object.h",
             "",
             "PyAPI_FUNC(int) PyObject_HasAttrString(PyObject *, const char *);"
         ),
         (
             "Include/object.h",
             "",
             "PyAPI_FUNC(PyObject *) PyObject_GetAttr(PyObject *, PyObject *);"
         ),
         (
             "Include/object.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030d0000)",
             "PyAPI_FUNC(int) PyObject_GetOptionalAttr(PyObject *, PyObject *, PyObject **);"
         ),
         (
             "Include/object.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030d0000)",
             "PyAPI_FUNC(int) PyObject_GetOptionalAttrString(PyObject *, const char *, PyObject **);"
         ),
         (
             "Include/object.h",
             "",
             "PyAPI_FUNC(int) PyObject_SetAttr(PyObject *, PyObject *, PyObject *);"
         ),
         (
             "Include/object.h",
             "",
             "PyAPI_FUNC(int) PyObject_DelAttr(PyObject *v, PyObject *name);"
         ),
         (
             "Include/object.h",
             "",
             "PyAPI_FUNC(int) PyObject_HasAttr(PyObject *, PyObject *);"
         ),
         (
             "Include/object.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030d0000)",
             "PyAPI_FUNC(int) PyObject_HasAttrWithError(PyObject *, PyObject *);"
         ),
         (
             "Include/object.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030d0000)",
             "PyAPI_FUNC(int) PyObject_HasAttrStringWithError(PyObject *, const char *);"
         ),
         (
             "Include/object.h",
             "",
             "PyAPI_FUNC(PyObject *) PyObject_SelfIter(PyObject *);"
         ),
         (
             "Include/object.h",
             "",
             "PyAPI_FUNC(PyObject *) PyObject_GenericGetAttr(PyObject *, PyObject *);"
         ),
         (
             "Include/object.h",
             "",
             "PyAPI_FUNC(int) PyObject_GenericSetAttr(PyObject *, PyObject *, PyObject *);"
         ),
         (
             "Include/object.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_FUNC(int) PyObject_GenericSetDict(PyObject *, PyObject *, void *);"
         ),
         ("Include/object.h", "", "PyAPI_FUNC(Py_hash_t) PyObject_Hash(PyObject *);"),
         (
             "Include/object.h",
             "",
             "PyAPI_FUNC(Py_hash_t) PyObject_HashNotImplemented(PyObject *);"
         ),
         ("Include/object.h", "", "PyAPI_FUNC(int) PyObject_IsTrue(PyObject *);"),
         ("Include/object.h", "", "PyAPI_FUNC(int) PyObject_Not(PyObject *);"),
         ("Include/object.h", "", "PyAPI_FUNC(int) PyCallable_Check(PyObject *);"),
         (
             "Include/object.h",
             "",
             "PyAPI_FUNC(void) PyObject_ClearWeakRefs(PyObject *);"
         ),
         ("Include/object.h", "", "PyAPI_FUNC(PyObject *) PyObject_Dir(PyObject *);"),
         ("Include/object.h", "", "PyAPI_FUNC(int) Py_ReprEnter(PyObject *);"),
         ("Include/object.h", "", "PyAPI_FUNC(void) Py_ReprLeave(PyObject *);"),
         (
             "Include/object.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030d0000)",
             "PyAPI_FUNC(PyObject*) Py_GetConstant(unsigned int constant_id);"
         ),
         (
             "Include/object.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030d0000)",
             "PyAPI_FUNC(PyObject*) Py_GetConstantBorrowed(unsigned int constant_id);"
         ),
         ("Include/object.h", "", "PyAPI_DATA(PyObject) _Py_NoneStruct;"),
         ("Include/object.h", "", "PyAPI_FUNC(int) Py_IsNone(PyObject *x);"),
         ("Include/object.h", "", "PyAPI_DATA(PyObject) _Py_NotImplementedStruct;"),
         (
             "Include/object.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030d0000)",
             "PyAPI_FUNC(PyObject *) PyType_GetModuleByDef(PyTypeObject *, PyModuleDef *);"
         ),
         (
             "Include/object.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030e0000)",
             "PyAPI_FUNC(int) PyType_Freeze(PyTypeObject *type);"
         ),
         ("Include/objimpl.h", "", "PyAPI_FUNC(void *) PyObject_Malloc(size_t size);"),
         (
             "Include/objimpl.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03050000)",
             "PyAPI_FUNC(void *) PyObject_Calloc(size_t nelem, size_t elsize);"
         ),
         (
             "Include/objimpl.h",
             "",
             "PyAPI_FUNC(void *) PyObject_Realloc(void *ptr, size_t new_size);"
         ),
         ("Include/objimpl.h", "", "PyAPI_FUNC(void) PyObject_Free(void *ptr);"),
         (
             "Include/objimpl.h",
             "",
             "PyAPI_FUNC(PyObject *) PyObject_Init(PyObject *, PyTypeObject *);"
         ),
         (
             "Include/objimpl.h",
             "",
             "PyAPI_FUNC(PyVarObject *) PyObject_InitVar(PyVarObject *, PyTypeObject *, Py_ssize_t);"
         ),
         (
             "Include/objimpl.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyObject_New(PyTypeObject *);"
         ),
         (
             "Include/objimpl.h",
             "",
             "PyAPI_FUNC(PyVarObject *) _PyObject_NewVar(PyTypeObject *, Py_ssize_t);"
         ),
         ("Include/objimpl.h", "", "PyAPI_FUNC(Py_ssize_t) PyGC_Collect(void);"),
         ("Include/objimpl.h", "", "PyAPI_FUNC(int) PyGC_Enable(void);"),
         ("Include/objimpl.h", "", "PyAPI_FUNC(int) PyGC_Disable(void);"),
         ("Include/objimpl.h", "", "PyAPI_FUNC(int) PyGC_IsEnabled(void);"),
         (
             "Include/objimpl.h",
             "",
             "PyAPI_FUNC(PyVarObject *) _PyObject_GC_Resize(PyVarObject *, Py_ssize_t);"
         ),
         (
             "Include/objimpl.h",
             "",
             "PyAPI_FUNC(PyObject *) _PyObject_GC_New(PyTypeObject *);"
         ),
         (
             "Include/objimpl.h",
             "",
             "PyAPI_FUNC(PyVarObject *) _PyObject_GC_NewVar(PyTypeObject *, Py_ssize_t);"
         ),
         ("Include/objimpl.h", "", "PyAPI_FUNC(void) PyObject_GC_Track(void *);"),
         ("Include/objimpl.h", "", "PyAPI_FUNC(void) PyObject_GC_UnTrack(void *);"),
         ("Include/objimpl.h", "", "PyAPI_FUNC(void) PyObject_GC_Del(void *);"),
         (
             "Include/objimpl.h",
             "",
             "PyAPI_FUNC(int) PyObject_GC_IsTracked(PyObject *);"
         ),
         (
             "Include/objimpl.h",
             "",
             "PyAPI_FUNC(int) PyObject_GC_IsFinalized(PyObject *);"
         ),
         (
             "Include/osmodule.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03060000)",
             "PyAPI_FUNC(PyObject *) PyOS_FSPath(PyObject *path);"
         ),
         (
             "Include/pybuffer.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030b0000)",
             "PyAPI_FUNC(int) PyObject_CheckBuffer(PyObject *obj);"
         ),
         (
             "Include/pybuffer.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030b0000)",
             "PyAPI_FUNC(int) PyObject_GetBuffer(PyObject *obj, Py_buffer *view, int flags);"
         ),
         (
             "Include/pybuffer.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030b0000)",
             "PyAPI_FUNC(void *) PyBuffer_GetPointer(const Py_buffer *view, const Py_ssize_t *indices);"
         ),
         (
             "Include/pybuffer.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030b0000)",
             "PyAPI_FUNC(Py_ssize_t) PyBuffer_SizeFromFormat(const char *format);"
         ),
         (
             "Include/pybuffer.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030b0000)",
             "PyAPI_FUNC(int) PyBuffer_ToContiguous(void *buf, const Py_buffer *view, Py_ssize_t len, char order);"
         ),
         (
             "Include/pybuffer.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030b0000)",
             "PyAPI_FUNC(int) PyBuffer_FromContiguous(const Py_buffer *view, const void *buf, Py_ssize_t len, char order);"
         ),
         (
             "Include/pybuffer.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030b0000)",
             "PyAPI_FUNC(int) PyObject_CopyData(PyObject *dest, PyObject *src);"
         ),
         (
             "Include/pybuffer.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030b0000)",
             "PyAPI_FUNC(int) PyBuffer_IsContiguous(const Py_buffer *view, char fort);"
         ),
         (
             "Include/pybuffer.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030b0000)",
             "PyAPI_FUNC(void) PyBuffer_FillContiguousStrides(int ndims, Py_ssize_t *shape, Py_ssize_t *strides, int itemsize, char fort);"
         ),
         (
             "Include/pybuffer.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030b0000)",
             "PyAPI_FUNC(int) PyBuffer_FillInfo(Py_buffer *view, PyObject *o, void *buf, Py_ssize_t len, int readonly, int flags);"
         ),
         (
             "Include/pybuffer.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030b0000)",
             "PyAPI_FUNC(void) PyBuffer_Release(Py_buffer *view);"
         ),
         ("Include/pycapsule.h", "", "PyAPI_DATA(PyTypeObject) PyCapsule_Type;"),
         (
             "Include/pycapsule.h",
             "",
             "PyAPI_FUNC(PyObject *) PyCapsule_New( void *pointer, const char *name, PyCapsule_Destructor destructor);"
         ),
         (
             "Include/pycapsule.h",
             "",
             "PyAPI_FUNC(void *) PyCapsule_GetPointer(PyObject *capsule, const char *name);"
         ),
         (
             "Include/pycapsule.h",
             "",
             "PyAPI_FUNC(PyCapsule_Destructor) PyCapsule_GetDestructor(PyObject *capsule);"
         ),
         (
             "Include/pycapsule.h",
             "",
             "PyAPI_FUNC(const char *) PyCapsule_GetName(PyObject *capsule);"
         ),
         (
             "Include/pycapsule.h",
             "",
             "PyAPI_FUNC(void *) PyCapsule_GetContext(PyObject *capsule);"
         ),
         (
             "Include/pycapsule.h",
             "",
             "PyAPI_FUNC(int) PyCapsule_IsValid(PyObject *capsule, const char *name);"
         ),
         (
             "Include/pycapsule.h",
             "",
             "PyAPI_FUNC(int) PyCapsule_SetPointer(PyObject *capsule, void *pointer);"
         ),
         (
             "Include/pycapsule.h",
             "",
             "PyAPI_FUNC(int) PyCapsule_SetDestructor(PyObject *capsule, PyCapsule_Destructor destructor);"
         ),
         (
             "Include/pycapsule.h",
             "",
             "PyAPI_FUNC(int) PyCapsule_SetName(PyObject *capsule, const char *name);"
         ),
         (
             "Include/pycapsule.h",
             "",
             "PyAPI_FUNC(int) PyCapsule_SetContext(PyObject *capsule, void *context);"
         ),
         (
             "Include/pycapsule.h",
             "",
             "PyAPI_FUNC(void *) PyCapsule_Import( const char *name, int no_block);"
         ),
         ("Include/pyerrors.h", "", "PyAPI_FUNC(void) PyErr_SetNone(PyObject *);"),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(void) PyErr_SetObject(PyObject *, PyObject *);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(void) PyErr_SetString( PyObject *exception, const char *string );"
         ),
         ("Include/pyerrors.h", "", "PyAPI_FUNC(PyObject *) PyErr_Occurred(void);"),
         ("Include/pyerrors.h", "", "PyAPI_FUNC(void) PyErr_Clear(void);"),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(void) PyErr_Fetch(PyObject **, PyObject **, PyObject **);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(void) PyErr_Restore(PyObject *, PyObject *, PyObject *);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(PyObject *) PyErr_GetRaisedException(void);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(void) PyErr_SetRaisedException(PyObject *);"
         ),
         (
             "Include/pyerrors.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030b0000)",
             "PyAPI_FUNC(PyObject*) PyErr_GetHandledException(void);"
         ),
         (
             "Include/pyerrors.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030b0000)",
             "PyAPI_FUNC(void) PyErr_SetHandledException(PyObject *);"
         ),
         (
             "Include/pyerrors.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_FUNC(void) PyErr_GetExcInfo(PyObject **, PyObject **, PyObject **);"
         ),
         (
             "Include/pyerrors.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_FUNC(void) PyErr_SetExcInfo(PyObject *, PyObject *, PyObject *);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(void) _Py_NO_RETURN Py_FatalError(const char *message);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(int) PyErr_GivenExceptionMatches(PyObject *, PyObject *);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(int) PyErr_ExceptionMatches(PyObject *);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(void) PyErr_NormalizeException(PyObject**, PyObject**, PyObject**);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(int) PyException_SetTraceback(PyObject *, PyObject *);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(PyObject *) PyException_GetTraceback(PyObject *);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(PyObject *) PyException_GetCause(PyObject *);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(void) PyException_SetCause(PyObject *, PyObject *);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(PyObject *) PyException_GetContext(PyObject *);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(void) PyException_SetContext(PyObject *, PyObject *);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(PyObject *) PyException_GetArgs(PyObject *);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(void) PyException_SetArgs(PyObject *, PyObject *);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(const char *) PyExceptionClass_Name(PyObject *);"
         ),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_BaseException;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_Exception;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_BaseExceptionGroup;"),
         (
             "Include/pyerrors.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03050000)",
             "PyAPI_DATA(PyObject *) PyExc_StopAsyncIteration;"
         ),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_StopIteration;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_GeneratorExit;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_ArithmeticError;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_LookupError;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_AssertionError;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_AttributeError;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_BufferError;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_EOFError;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_FloatingPointError;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_OSError;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_ImportError;"),
         (
             "Include/pyerrors.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03060000)",
             "PyAPI_DATA(PyObject *) PyExc_ModuleNotFoundError;"
         ),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_IndexError;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_KeyError;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_KeyboardInterrupt;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_MemoryError;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_NameError;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_OverflowError;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_RuntimeError;"),
         (
             "Include/pyerrors.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03050000)",
             "PyAPI_DATA(PyObject *) PyExc_RecursionError;"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_DATA(PyObject *) PyExc_NotImplementedError;"
         ),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_SyntaxError;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_IndentationError;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_TabError;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_ReferenceError;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_SystemError;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_SystemExit;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_TypeError;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_UnboundLocalError;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_UnicodeError;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_UnicodeEncodeError;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_UnicodeDecodeError;"),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_DATA(PyObject *) PyExc_UnicodeTranslateError;"
         ),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_ValueError;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_ZeroDivisionError;"),
         (
             "Include/pyerrors.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_DATA(PyObject *) PyExc_BlockingIOError;"
         ),
         (
             "Include/pyerrors.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_DATA(PyObject *) PyExc_BrokenPipeError;"
         ),
         (
             "Include/pyerrors.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_DATA(PyObject *) PyExc_ChildProcessError;"
         ),
         (
             "Include/pyerrors.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_DATA(PyObject *) PyExc_ConnectionError;"
         ),
         (
             "Include/pyerrors.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_DATA(PyObject *) PyExc_ConnectionAbortedError;"
         ),
         (
             "Include/pyerrors.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_DATA(PyObject *) PyExc_ConnectionRefusedError;"
         ),
         (
             "Include/pyerrors.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_DATA(PyObject *) PyExc_ConnectionResetError;"
         ),
         (
             "Include/pyerrors.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_DATA(PyObject *) PyExc_FileExistsError;"
         ),
         (
             "Include/pyerrors.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_DATA(PyObject *) PyExc_FileNotFoundError;"
         ),
         (
             "Include/pyerrors.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_DATA(PyObject *) PyExc_InterruptedError;"
         ),
         (
             "Include/pyerrors.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_DATA(PyObject *) PyExc_IsADirectoryError;"
         ),
         (
             "Include/pyerrors.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_DATA(PyObject *) PyExc_NotADirectoryError;"
         ),
         (
             "Include/pyerrors.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_DATA(PyObject *) PyExc_PermissionError;"
         ),
         (
             "Include/pyerrors.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_DATA(PyObject *) PyExc_ProcessLookupError;"
         ),
         (
             "Include/pyerrors.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_DATA(PyObject *) PyExc_TimeoutError;"
         ),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_EnvironmentError;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_IOError;"),
         (
             "Include/pyerrors.h",
             "defined(MS_WINDOWS)",
             "PyAPI_DATA(PyObject *) PyExc_WindowsError;"
         ),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_Warning;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_UserWarning;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_DeprecationWarning;"),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_DATA(PyObject *) PyExc_PendingDeprecationWarning;"
         ),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_SyntaxWarning;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_RuntimeWarning;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_FutureWarning;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_ImportWarning;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_UnicodeWarning;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_BytesWarning;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_EncodingWarning;"),
         ("Include/pyerrors.h", "", "PyAPI_DATA(PyObject *) PyExc_ResourceWarning;"),
         ("Include/pyerrors.h", "", "PyAPI_FUNC(int) PyErr_BadArgument(void);"),
         ("Include/pyerrors.h", "", "PyAPI_FUNC(PyObject *) PyErr_NoMemory(void);"),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(PyObject *) PyErr_SetFromErrno(PyObject *);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(PyObject *) PyErr_SetFromErrnoWithFilenameObject( PyObject *, PyObject *);"
         ),
         (
             "Include/pyerrors.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03040000)",
             "PyAPI_FUNC(PyObject *) PyErr_SetFromErrnoWithFilenameObjects( PyObject *, PyObject *, PyObject *);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(PyObject *) PyErr_SetFromErrnoWithFilename( PyObject *exc, const char *filename );"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(PyObject *) PyErr_Format( PyObject *exception, const char *format, ... );"
         ),
         (
             "Include/pyerrors.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03050000)",
             "PyAPI_FUNC(PyObject *) PyErr_FormatV( PyObject *exception, const char *format, va_list vargs);"
         ),
         (
             "Include/pyerrors.h",
             "defined(MS_WINDOWS)",
             "PyAPI_FUNC(PyObject *) PyErr_SetFromWindowsErrWithFilename( int ierr, const char *filename );"
         ),
         (
             "Include/pyerrors.h",
             "defined(MS_WINDOWS)",
             "PyAPI_FUNC(PyObject *) PyErr_SetFromWindowsErr(int);"
         ),
         (
             "Include/pyerrors.h",
             "defined(MS_WINDOWS)",
             "PyAPI_FUNC(PyObject *) PyErr_SetExcFromWindowsErrWithFilenameObject( PyObject *,int, PyObject *);"
         ),
         (
             "Include/pyerrors.h",
             "defined(MS_WINDOWS) && (!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03040000)",
             "PyAPI_FUNC(PyObject *) PyErr_SetExcFromWindowsErrWithFilenameObjects( PyObject *,int, PyObject *, PyObject *);"
         ),
         (
             "Include/pyerrors.h",
             "defined(MS_WINDOWS)",
             "PyAPI_FUNC(PyObject *) PyErr_SetExcFromWindowsErrWithFilename( PyObject *exc, int ierr, const char *filename );"
         ),
         (
             "Include/pyerrors.h",
             "defined(MS_WINDOWS)",
             "PyAPI_FUNC(PyObject *) PyErr_SetExcFromWindowsErr(PyObject *, int);"
         ),
         (
             "Include/pyerrors.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03060000)",
             "PyAPI_FUNC(PyObject *) PyErr_SetImportErrorSubclass(PyObject *, PyObject *, PyObject *, PyObject *);"
         ),
         (
             "Include/pyerrors.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_FUNC(PyObject *) PyErr_SetImportError(PyObject *, PyObject *, PyObject *);"
         ),
         ("Include/pyerrors.h", "", "PyAPI_FUNC(void) PyErr_BadInternalCall(void);"),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(void) _PyErr_BadInternalCall(const char *filename, int lineno);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(PyObject *) PyErr_NewException( const char *name, PyObject *base, PyObject *dict);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(PyObject *) PyErr_NewExceptionWithDoc( const char *name, const char *doc, PyObject *base, PyObject *dict);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(void) PyErr_WriteUnraisable(PyObject *);"
         ),
         ("Include/pyerrors.h", "", "PyAPI_FUNC(int) PyErr_CheckSignals(void);"),
         ("Include/pyerrors.h", "", "PyAPI_FUNC(void) PyErr_SetInterrupt(void);"),
         (
             "Include/pyerrors.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030A0000)",
             "PyAPI_FUNC(int) PyErr_SetInterruptEx(int signum);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(void) PyErr_SyntaxLocation( const char *filename, int lineno);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(void) PyErr_SyntaxLocationEx( const char *filename, int lineno, int col_offset);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(PyObject *) PyErr_ProgramText( const char *filename, int lineno);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(PyObject *) PyUnicodeDecodeError_Create( const char *encoding, const char *object, Py_ssize_t length, Py_ssize_t start, Py_ssize_t end, const char *reason );"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(PyObject *) PyUnicodeEncodeError_GetEncoding(PyObject *);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(PyObject *) PyUnicodeDecodeError_GetEncoding(PyObject *);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(PyObject *) PyUnicodeEncodeError_GetObject(PyObject *);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(PyObject *) PyUnicodeDecodeError_GetObject(PyObject *);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(PyObject *) PyUnicodeTranslateError_GetObject(PyObject *);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(int) PyUnicodeEncodeError_GetStart(PyObject *, Py_ssize_t *);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(int) PyUnicodeDecodeError_GetStart(PyObject *, Py_ssize_t *);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(int) PyUnicodeTranslateError_GetStart(PyObject *, Py_ssize_t *);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(int) PyUnicodeEncodeError_SetStart(PyObject *, Py_ssize_t);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(int) PyUnicodeDecodeError_SetStart(PyObject *, Py_ssize_t);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(int) PyUnicodeTranslateError_SetStart(PyObject *, Py_ssize_t);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(int) PyUnicodeEncodeError_GetEnd(PyObject *, Py_ssize_t *);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(int) PyUnicodeDecodeError_GetEnd(PyObject *, Py_ssize_t *);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(int) PyUnicodeTranslateError_GetEnd(PyObject *, Py_ssize_t *);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(int) PyUnicodeEncodeError_SetEnd(PyObject *, Py_ssize_t);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(int) PyUnicodeDecodeError_SetEnd(PyObject *, Py_ssize_t);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(int) PyUnicodeTranslateError_SetEnd(PyObject *, Py_ssize_t);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(PyObject *) PyUnicodeEncodeError_GetReason(PyObject *);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(PyObject *) PyUnicodeDecodeError_GetReason(PyObject *);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(PyObject *) PyUnicodeTranslateError_GetReason(PyObject *);"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(int) PyUnicodeEncodeError_SetReason( PyObject *exc, const char *reason );"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(int) PyUnicodeDecodeError_SetReason( PyObject *exc, const char *reason );"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(int) PyUnicodeTranslateError_SetReason( PyObject *exc, const char *reason );"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(int) PyOS_snprintf(char *str, size_t size, const char *format, ...) Py_GCC_ATTRIBUTE((format(printf, 3, 4)));"
         ),
         (
             "Include/pyerrors.h",
             "",
             "PyAPI_FUNC(int) PyOS_vsnprintf(char *str, size_t size, const char *format, va_list va) Py_GCC_ATTRIBUTE((format(printf, 3, 0)));"
         ),
         (
             "Include/pyframe.h",
             "",
             "PyAPI_FUNC(int) PyFrame_GetLineNumber(PyFrameObject *);"
         ),
         (
             "Include/pyframe.h",
             "",
             "PyAPI_FUNC(PyCodeObject *) PyFrame_GetCode(PyFrameObject *frame);"
         ),
         ("Include/pylifecycle.h", "", "PyAPI_FUNC(void) Py_Initialize(void);"),
         ("Include/pylifecycle.h", "", "PyAPI_FUNC(void) Py_InitializeEx(int);"),
         ("Include/pylifecycle.h", "", "PyAPI_FUNC(void) Py_Finalize(void);"),
         (
             "Include/pylifecycle.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03060000)",
             "PyAPI_FUNC(int) Py_FinalizeEx(void);"
         ),
         ("Include/pylifecycle.h", "", "PyAPI_FUNC(int) Py_IsInitialized(void);"),
         (
             "Include/pylifecycle.h",
             "",
             "PyAPI_FUNC(PyThreadState *) Py_NewInterpreter(void);"
         ),
         (
             "Include/pylifecycle.h",
             "",
             "PyAPI_FUNC(void) Py_EndInterpreter(PyThreadState *);"
         ),
         (
             "Include/pylifecycle.h",
             "",
             "PyAPI_FUNC(int) Py_AtExit(void (*func)(void));"
         ),
         ("Include/pylifecycle.h", "", "PyAPI_FUNC(void) _Py_NO_RETURN Py_Exit(int);"),
         (
             "Include/pylifecycle.h",
             "",
             "PyAPI_FUNC(int) Py_Main(int argc, wchar_t **argv);"
         ),
         (
             "Include/pylifecycle.h",
             "",
             "PyAPI_FUNC(int) Py_BytesMain(int argc, char **argv);"
         ),
         (
             "Include/pylifecycle.h",
             "",
             "Py_DEPRECATED(3.11) PyAPI_FUNC(void) Py_SetProgramName(const wchar_t *);"
         ),
         (
             "Include/pylifecycle.h",
             "",
             "Py_DEPRECATED(3.13) PyAPI_FUNC(wchar_t *) Py_GetProgramName(void);"
         ),
         (
             "Include/pylifecycle.h",
             "",
             "Py_DEPRECATED(3.11) PyAPI_FUNC(void) Py_SetPythonHome(const wchar_t *);"
         ),
         (
             "Include/pylifecycle.h",
             "",
             "Py_DEPRECATED(3.13) PyAPI_FUNC(wchar_t *) Py_GetPythonHome(void);"
         ),
         (
             "Include/pylifecycle.h",
             "",
             "Py_DEPRECATED(3.13) PyAPI_FUNC(wchar_t *) Py_GetProgramFullPath(void);"
         ),
         (
             "Include/pylifecycle.h",
             "",
             "Py_DEPRECATED(3.13) PyAPI_FUNC(wchar_t *) Py_GetPrefix(void);"
         ),
         (
             "Include/pylifecycle.h",
             "",
             "Py_DEPRECATED(3.13) PyAPI_FUNC(wchar_t *) Py_GetExecPrefix(void);"
         ),
         (
             "Include/pylifecycle.h",
             "",
             "Py_DEPRECATED(3.13) PyAPI_FUNC(wchar_t *) Py_GetPath(void);"
         ),
         ("Include/pylifecycle.h", "", "PyAPI_FUNC(const char *) Py_GetVersion(void);"),
         (
             "Include/pylifecycle.h",
             "",
             "PyAPI_FUNC(const char *) Py_GetPlatform(void);"
         ),
         (
             "Include/pylifecycle.h",
             "",
             "PyAPI_FUNC(const char *) Py_GetCopyright(void);"
         ),
         (
             "Include/pylifecycle.h",
             "",
             "PyAPI_FUNC(const char *) Py_GetCompiler(void);"
         ),
         (
             "Include/pylifecycle.h",
             "",
             "PyAPI_FUNC(const char *) Py_GetBuildInfo(void);"
         ),
         (
             "Include/pylifecycle.h",
             "",
             "PyAPI_FUNC(PyOS_sighandler_t) PyOS_getsig(int);"
         ),
         (
             "Include/pylifecycle.h",
             "",
             "PyAPI_FUNC(PyOS_sighandler_t) PyOS_setsig(int, PyOS_sighandler_t);"
         ),
         (
             "Include/pylifecycle.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030B0000)",
             "PyAPI_DATA(const unsigned long) Py_Version;"
         ),
         (
             "Include/pylifecycle.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030D0000)",
             "PyAPI_FUNC(int) Py_IsFinalizing(void);"
         ),
         (
             "Include/pymacro.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030E0000)",
             "PyAPI_FUNC(uint32_t) Py_PACK_FULL_VERSION(int x, int y, int z, int level, int serial);"
         ),
         (
             "Include/pymacro.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030E0000)",
             "PyAPI_FUNC(uint32_t) Py_PACK_VERSION(int x, int y);"
         ),
         ("Include/pymem.h", "", "PyAPI_FUNC(void *) PyMem_Malloc(size_t size);"),
         (
             "Include/pymem.h",
             "",
             "PyAPI_FUNC(void *) PyMem_Calloc(size_t nelem, size_t elsize);"
         ),
         (
             "Include/pymem.h",
             "",
             "PyAPI_FUNC(void *) PyMem_Realloc(void *ptr, size_t new_size);"
         ),
         ("Include/pymem.h", "", "PyAPI_FUNC(void) PyMem_Free(void *ptr);"),
         (
             "Include/pymem.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030d0000)",
             "PyAPI_FUNC(void *) PyMem_RawMalloc(size_t size);"
         ),
         (
             "Include/pymem.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030d0000)",
             "PyAPI_FUNC(void *) PyMem_RawCalloc(size_t nelem, size_t elsize);"
         ),
         (
             "Include/pymem.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030d0000)",
             "PyAPI_FUNC(void *) PyMem_RawRealloc(void *ptr, size_t new_size);"
         ),
         (
             "Include/pymem.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030d0000)",
             "PyAPI_FUNC(void) PyMem_RawFree(void *ptr);"
         ),
         (
             "Include/pystate.h",
             "",
             "PyAPI_FUNC(PyInterpreterState *) PyInterpreterState_New(void);"
         ),
         (
             "Include/pystate.h",
             "",
             "PyAPI_FUNC(void) PyInterpreterState_Clear(PyInterpreterState *);"
         ),
         (
             "Include/pystate.h",
             "",
             "PyAPI_FUNC(void) PyInterpreterState_Delete(PyInterpreterState *);"
         ),
         (
             "Include/pystate.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03090000)",
             "PyAPI_FUNC(PyInterpreterState *) PyInterpreterState_Get(void);"
         ),
         (
             "Include/pystate.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03080000)",
             "PyAPI_FUNC(PyObject *) PyInterpreterState_GetDict(PyInterpreterState *);"
         ),
         (
             "Include/pystate.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03070000)",
             "PyAPI_FUNC(int64_t) PyInterpreterState_GetID(PyInterpreterState *);"
         ),
         (
             "Include/pystate.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_FUNC(int) PyState_AddModule(PyObject*, PyModuleDef*);"
         ),
         (
             "Include/pystate.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_FUNC(int) PyState_RemoveModule(PyModuleDef*);"
         ),
         (
             "Include/pystate.h",
             "",
             "PyAPI_FUNC(PyObject*) PyState_FindModule(PyModuleDef*);"
         ),
         (
             "Include/pystate.h",
             "",
             "PyAPI_FUNC(PyThreadState *) PyThreadState_New(PyInterpreterState *);"
         ),
         (
             "Include/pystate.h",
             "",
             "PyAPI_FUNC(void) PyThreadState_Clear(PyThreadState *);"
         ),
         (
             "Include/pystate.h",
             "",
             "PyAPI_FUNC(void) PyThreadState_Delete(PyThreadState *);"
         ),
         (
             "Include/pystate.h",
             "",
             "PyAPI_FUNC(PyThreadState *) PyThreadState_Get(void);"
         ),
         (
             "Include/pystate.h",
             "",
             "PyAPI_FUNC(PyThreadState *) PyThreadState_Swap(PyThreadState *);"
         ),
         (
             "Include/pystate.h",
             "",
             "PyAPI_FUNC(PyObject *) PyThreadState_GetDict(void);"
         ),
         (
             "Include/pystate.h",
             "",
             "PyAPI_FUNC(int) PyThreadState_SetAsyncExc(unsigned long, PyObject *);"
         ),
         (
             "Include/pystate.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03090000)",
             "PyAPI_FUNC(PyInterpreterState*) PyThreadState_GetInterpreter(PyThreadState *tstate);"
         ),
         (
             "Include/pystate.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03090000)",
             "PyAPI_FUNC(PyFrameObject*) PyThreadState_GetFrame(PyThreadState *tstate);"
         ),
         (
             "Include/pystate.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03090000)",
             "PyAPI_FUNC(uint64_t) PyThreadState_GetID(PyThreadState *tstate);"
         ),
         (
             "Include/pystate.h",
             "",
             "PyAPI_FUNC(PyGILState_STATE) PyGILState_Ensure(void);"
         ),
         (
             "Include/pystate.h",
             "",
             "PyAPI_FUNC(void) PyGILState_Release(PyGILState_STATE);"
         ),
         (
             "Include/pystate.h",
             "",
             "PyAPI_FUNC(PyThreadState *) PyGILState_GetThisThreadState(void);"
         ),
         (
             "Include/pystrcmp.h",
             "",
             "PyAPI_FUNC(int) PyOS_mystrnicmp(const char *, const char *, Py_ssize_t);"
         ),
         (
             "Include/pystrcmp.h",
             "",
             "PyAPI_FUNC(int) PyOS_mystricmp(const char *, const char *);"
         ),
         (
             "Include/pystrtod.h",
             "",
             "PyAPI_FUNC(double) PyOS_string_to_double(const char *str, char **endptr, PyObject *overflow_exception);"
         ),
         (
             "Include/pystrtod.h",
             "",
             "PyAPI_FUNC(char *) PyOS_double_to_string(double val, char format_code, int precision, int flags, int *type);"
         ),
         (
             "Include/pythonrun.h",
             "",
             "PyAPI_FUNC(PyObject *) Py_CompileString(const char *, const char *, int);"
         ),
         ("Include/pythonrun.h", "", "PyAPI_FUNC(void) PyErr_Print(void);"),
         ("Include/pythonrun.h", "", "PyAPI_FUNC(void) PyErr_PrintEx(int);"),
         (
             "Include/pythonrun.h",
             "",
             "PyAPI_FUNC(void) PyErr_Display(PyObject *, PyObject *, PyObject *);"
         ),
         (
             "Include/pythonrun.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030C0000)",
             "PyAPI_FUNC(void) PyErr_DisplayException(PyObject *);"
         ),
         ("Include/pythonrun.h", "", "PyAPI_DATA(int) (*PyOS_InputHook)(void);"),
         (
             "Include/pythonrun.h",
             "defined(USE_STACKCHECK)",
             "PyAPI_FUNC(int) PyOS_CheckStack(void);"
         ),
         ("Include/pythread.h", "", "PyAPI_FUNC(void) PyThread_init_thread(void);"),
         (
             "Include/pythread.h",
             "",
             "PyAPI_FUNC(unsigned long) PyThread_start_new_thread(void (*)(void *), void *);"
         ),
         (
             "Include/pythread.h",
             "",
             "Py_DEPRECATED(3.14) PyAPI_FUNC(void) _Py_NO_RETURN PyThread_exit_thread(void);"
         ),
         (
             "Include/pythread.h",
             "",
             "PyAPI_FUNC(unsigned long) PyThread_get_thread_ident(void);"
         ),
         (
             "Include/pythread.h",
             "((defined(__APPLE__) || defined(__linux__) || defined(_WIN32) || defined(__FreeBSD__) || defined(__FreeBSD_kernel__) || defined(__OpenBSD__) || defined(__NetBSD__) || defined(__DragonFly__) || defined(_AIX)))",
             "PyAPI_FUNC(unsigned long) PyThread_get_thread_native_id(void);"
         ),
         (
             "Include/pythread.h",
             "",
             "PyAPI_FUNC(PyThread_type_lock) PyThread_allocate_lock(void);"
         ),
         (
             "Include/pythread.h",
             "",
             "PyAPI_FUNC(void) PyThread_free_lock(PyThread_type_lock);"
         ),
         (
             "Include/pythread.h",
             "",
             "PyAPI_FUNC(int) PyThread_acquire_lock(PyThread_type_lock, int);"
         ),
         (
             "Include/pythread.h",
             "",
             "PyAPI_FUNC(PyLockStatus) PyThread_acquire_lock_timed(PyThread_type_lock, PY_TIMEOUT_T microseconds, int intr_flag);"
         ),
         (
             "Include/pythread.h",
             "",
             "PyAPI_FUNC(void) PyThread_release_lock(PyThread_type_lock);"
         ),
         ("Include/pythread.h", "", "PyAPI_FUNC(size_t) PyThread_get_stacksize(void);"),
         ("Include/pythread.h", "", "PyAPI_FUNC(int) PyThread_set_stacksize(size_t);"),
         (
             "Include/pythread.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_FUNC(PyObject*) PyThread_GetInfo(void);"
         ),
         (
             "Include/pythread.h",
             "",
             "Py_DEPRECATED(3.7) PyAPI_FUNC(int) PyThread_create_key(void);"
         ),
         (
             "Include/pythread.h",
             "",
             "Py_DEPRECATED(3.7) PyAPI_FUNC(void) PyThread_delete_key(int key);"
         ),
         (
             "Include/pythread.h",
             "",
             "Py_DEPRECATED(3.7) PyAPI_FUNC(int) PyThread_set_key_value(int key, void *value);"
         ),
         (
             "Include/pythread.h",
             "",
             "Py_DEPRECATED(3.7) PyAPI_FUNC(void *) PyThread_get_key_value(int key);"
         ),
         (
             "Include/pythread.h",
             "",
             "Py_DEPRECATED(3.7) PyAPI_FUNC(void) PyThread_delete_key_value(int key);"
         ),
         (
             "Include/pythread.h",
             "",
             "Py_DEPRECATED(3.7) PyAPI_FUNC(void) PyThread_ReInitTLS(void);"
         ),
         (
             "Include/pythread.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03070000)",
             "PyAPI_FUNC(Py_tss_t *) PyThread_tss_alloc(void);"
         ),
         (
             "Include/pythread.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03070000)",
             "PyAPI_FUNC(void) PyThread_tss_free(Py_tss_t *key);"
         ),
         (
             "Include/pythread.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03070000)",
             "PyAPI_FUNC(int) PyThread_tss_is_created(Py_tss_t *key);"
         ),
         (
             "Include/pythread.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03070000)",
             "PyAPI_FUNC(int) PyThread_tss_create(Py_tss_t *key);"
         ),
         (
             "Include/pythread.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03070000)",
             "PyAPI_FUNC(void) PyThread_tss_delete(Py_tss_t *key);"
         ),
         (
             "Include/pythread.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03070000)",
             "PyAPI_FUNC(int) PyThread_tss_set(Py_tss_t *key, void *value);"
         ),
         (
             "Include/pythread.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03070000)",
             "PyAPI_FUNC(void *) PyThread_tss_get(Py_tss_t *key);"
         ),
         ("Include/rangeobject.h", "", "PyAPI_DATA(PyTypeObject) PyRange_Type;"),
         ("Include/rangeobject.h", "", "PyAPI_DATA(PyTypeObject) PyRangeIter_Type;"),
         (
             "Include/rangeobject.h",
             "",
             "PyAPI_DATA(PyTypeObject) PyLongRangeIter_Type;"
         ),
         ("Include/refcount.h", "", "PyAPI_FUNC(Py_ssize_t) Py_REFCNT(PyObject *ob);"),
         (
             "Include/refcount.h",
             "",
             "PyAPI_FUNC(void) _Py_SetRefcnt(PyObject *ob, Py_ssize_t refcnt);"
         ),
         (
             "Include/refcount.h",
             "(defined(Py_REF_DEBUG) && !defined(Py_LIMITED_API))",
             "PyAPI_FUNC(void) _Py_NegativeRefcount(const char *filename, int lineno, PyObject *op);"
         ),
         (
             "Include/refcount.h",
             "(defined(Py_REF_DEBUG) && !defined(Py_LIMITED_API))",
             "PyAPI_FUNC(void) _Py_INCREF_IncRefTotal(void);"
         ),
         (
             "Include/refcount.h",
             "(defined(Py_REF_DEBUG) && !defined(Py_LIMITED_API))",
             "PyAPI_FUNC(void) _Py_DECREF_DecRefTotal(void);"
         ),
         ("Include/refcount.h", "", "PyAPI_FUNC(void) _Py_Dealloc(PyObject *);"),
         ("Include/refcount.h", "", "PyAPI_FUNC(void) Py_IncRef(PyObject *);"),
         ("Include/refcount.h", "", "PyAPI_FUNC(void) Py_DecRef(PyObject *);"),
         ("Include/refcount.h", "", "PyAPI_FUNC(void) _Py_IncRef(PyObject *);"),
         ("Include/refcount.h", "", "PyAPI_FUNC(void) _Py_DecRef(PyObject *);"),
         (
             "Include/refcount.h",
             "(!defined(Py_LIMITED_API) && defined(Py_GIL_DISABLED))",
             "PyAPI_FUNC(void) _Py_DecRefShared(PyObject *);"
         ),
         (
             "Include/refcount.h",
             "(!defined(Py_LIMITED_API) && defined(Py_GIL_DISABLED))",
             "PyAPI_FUNC(void) _Py_DecRefSharedDebug(PyObject *, const char *, int);"
         ),
         (
             "Include/refcount.h",
             "(!defined(Py_LIMITED_API) && defined(Py_GIL_DISABLED))",
             "PyAPI_FUNC(void) _Py_MergeZeroLocalRefcount(PyObject *);"
         ),
         ("Include/refcount.h", "", "PyAPI_FUNC(PyObject*) Py_NewRef(PyObject *obj);"),
         ("Include/refcount.h", "", "PyAPI_FUNC(PyObject*) Py_XNewRef(PyObject *obj);"),
         ("Include/setobject.h", "", "PyAPI_DATA(PyTypeObject) PySet_Type;"),
         ("Include/setobject.h", "", "PyAPI_DATA(PyTypeObject) PyFrozenSet_Type;"),
         ("Include/setobject.h", "", "PyAPI_DATA(PyTypeObject) PySetIter_Type;"),
         ("Include/setobject.h", "", "PyAPI_FUNC(PyObject *) PySet_New(PyObject *);"),
         (
             "Include/setobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyFrozenSet_New(PyObject *);"
         ),
         (
             "Include/setobject.h",
             "",
             "PyAPI_FUNC(int) PySet_Add(PyObject *set, PyObject *key);"
         ),
         ("Include/setobject.h", "", "PyAPI_FUNC(int) PySet_Clear(PyObject *set);"),
         (
             "Include/setobject.h",
             "",
             "PyAPI_FUNC(int) PySet_Contains(PyObject *anyset, PyObject *key);"
         ),
         (
             "Include/setobject.h",
             "",
             "PyAPI_FUNC(int) PySet_Discard(PyObject *set, PyObject *key);"
         ),
         (
             "Include/setobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PySet_Pop(PyObject *set);"
         ),
         (
             "Include/setobject.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) PySet_Size(PyObject *anyset);"
         ),
         ("Include/sliceobject.h", "", "PyAPI_DATA(PyObject) _Py_EllipsisObject;"),
         ("Include/sliceobject.h", "", "PyAPI_DATA(PyTypeObject) PySlice_Type;"),
         ("Include/sliceobject.h", "", "PyAPI_DATA(PyTypeObject) PyEllipsis_Type;"),
         (
             "Include/sliceobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PySlice_New(PyObject* start, PyObject* stop, PyObject* step);"
         ),
         (
             "Include/sliceobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(PyObject *) _PySlice_FromIndices(Py_ssize_t start, Py_ssize_t stop);"
         ),
         (
             "Include/sliceobject.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) _PySlice_GetLongIndices(PySliceObject *self, PyObject *length, PyObject **start_ptr, PyObject **stop_ptr, PyObject **step_ptr);"
         ),
         (
             "Include/sliceobject.h",
             "",
             "PyAPI_FUNC(int) PySlice_GetIndices(PyObject *r, Py_ssize_t length, Py_ssize_t *start, Py_ssize_t *stop, Py_ssize_t *step);"
         ),
         (
             "Include/sliceobject.h",
             "",
             "Py_DEPRECATED(3.7) PyAPI_FUNC(int) PySlice_GetIndicesEx(PyObject *r, Py_ssize_t length, Py_ssize_t *start, Py_ssize_t *stop, Py_ssize_t *step, Py_ssize_t *slicelength);"
         ),
         (
             "Include/sliceobject.h",
             "(!defined(Py_LIMITED_API) || (Py_LIMITED_API+0 >= 0x03050400 && Py_LIMITED_API+0 < 0x03060000) || Py_LIMITED_API+0 >= 0x03060100)",
             "PyAPI_FUNC(int) PySlice_Unpack(PyObject *slice, Py_ssize_t *start, Py_ssize_t *stop, Py_ssize_t *step);"
         ),
         (
             "Include/sliceobject.h",
             "(!defined(Py_LIMITED_API) || (Py_LIMITED_API+0 >= 0x03050400 && Py_LIMITED_API+0 < 0x03060000) || Py_LIMITED_API+0 >= 0x03060100)",
             "PyAPI_FUNC(Py_ssize_t) PySlice_AdjustIndices(Py_ssize_t length, Py_ssize_t *start, Py_ssize_t *stop, Py_ssize_t step);"
         ),
         (
             "Include/structseq.h",
             "",
             "PyAPI_DATA(const char * const) PyStructSequence_UnnamedField;"
         ),
         (
             "Include/structseq.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(void) PyStructSequence_InitType(PyTypeObject *type, PyStructSequence_Desc *desc);"
         ),
         (
             "Include/structseq.h",
             "!defined(Py_LIMITED_API)",
             "PyAPI_FUNC(int) PyStructSequence_InitType2(PyTypeObject *type, PyStructSequence_Desc *desc);"
         ),
         (
             "Include/structseq.h",
             "",
             "PyAPI_FUNC(PyTypeObject*) PyStructSequence_NewType(PyStructSequence_Desc *desc);"
         ),
         (
             "Include/structseq.h",
             "",
             "PyAPI_FUNC(PyObject *) PyStructSequence_New(PyTypeObject* type);"
         ),
         (
             "Include/structseq.h",
             "",
             "PyAPI_FUNC(void) PyStructSequence_SetItem(PyObject*, Py_ssize_t, PyObject*);"
         ),
         (
             "Include/structseq.h",
             "",
             "PyAPI_FUNC(PyObject*) PyStructSequence_GetItem(PyObject*, Py_ssize_t);"
         ),
         (
             "Include/sysmodule.h",
             "",
             "PyAPI_FUNC(PyObject *) PySys_GetObject(const char *);"
         ),
         (
             "Include/sysmodule.h",
             "",
             "PyAPI_FUNC(int) PySys_SetObject(const char *, PyObject *);"
         ),
         (
             "Include/sysmodule.h",
             "",
             "Py_DEPRECATED(3.11) PyAPI_FUNC(void) PySys_SetArgv(int, wchar_t **);"
         ),
         (
             "Include/sysmodule.h",
             "",
             "Py_DEPRECATED(3.11) PyAPI_FUNC(void) PySys_SetArgvEx(int, wchar_t **, int);"
         ),
         (
             "Include/sysmodule.h",
             "",
             "PyAPI_FUNC(void) PySys_WriteStdout(const char *format, ...) Py_GCC_ATTRIBUTE((format(printf, 1, 2)));"
         ),
         (
             "Include/sysmodule.h",
             "",
             "PyAPI_FUNC(void) PySys_WriteStderr(const char *format, ...) Py_GCC_ATTRIBUTE((format(printf, 1, 2)));"
         ),
         (
             "Include/sysmodule.h",
             "",
             "PyAPI_FUNC(void) PySys_FormatStdout(const char *format, ...);"
         ),
         (
             "Include/sysmodule.h",
             "",
             "PyAPI_FUNC(void) PySys_FormatStderr(const char *format, ...);"
         ),
         (
             "Include/sysmodule.h",
             "",
             "Py_DEPRECATED(3.13) PyAPI_FUNC(void) PySys_ResetWarnOptions(void);"
         ),
         ("Include/sysmodule.h", "", "PyAPI_FUNC(PyObject *) PySys_GetXOptions(void);"),
         (
             "Include/traceback.h",
             "",
             "PyAPI_FUNC(int) PyTraceBack_Here(PyFrameObject *);"
         ),
         (
             "Include/traceback.h",
             "",
             "PyAPI_FUNC(int) PyTraceBack_Print(PyObject *, PyObject *);"
         ),
         ("Include/traceback.h", "", "PyAPI_DATA(PyTypeObject) PyTraceBack_Type;"),
         ("Include/tupleobject.h", "", "PyAPI_DATA(PyTypeObject) PyTuple_Type;"),
         ("Include/tupleobject.h", "", "PyAPI_DATA(PyTypeObject) PyTupleIter_Type;"),
         (
             "Include/tupleobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyTuple_New(Py_ssize_t size);"
         ),
         (
             "Include/tupleobject.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) PyTuple_Size(PyObject *);"
         ),
         (
             "Include/tupleobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyTuple_GetItem(PyObject *, Py_ssize_t);"
         ),
         (
             "Include/tupleobject.h",
             "",
             "PyAPI_FUNC(int) PyTuple_SetItem(PyObject *, Py_ssize_t, PyObject *);"
         ),
         (
             "Include/tupleobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyTuple_GetSlice(PyObject *, Py_ssize_t, Py_ssize_t);"
         ),
         (
             "Include/tupleobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyTuple_Pack(Py_ssize_t, ...);"
         ),
         ("Include/unicodeobject.h", "", "PyAPI_DATA(PyTypeObject) PyUnicode_Type;"),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_DATA(PyTypeObject) PyUnicodeIter_Type;"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_FromStringAndSize( const char *u, Py_ssize_t size );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_FromString( const char *u );"
         ),
         (
             "Include/unicodeobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_FUNC(PyObject*) PyUnicode_Substring( PyObject *str, Py_ssize_t start, Py_ssize_t end);"
         ),
         (
             "Include/unicodeobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_FUNC(Py_UCS4*) PyUnicode_AsUCS4( PyObject *unicode, Py_UCS4* buffer, Py_ssize_t buflen, int copy_null);"
         ),
         (
             "Include/unicodeobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_FUNC(Py_UCS4*) PyUnicode_AsUCS4Copy(PyObject *unicode);"
         ),
         (
             "Include/unicodeobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_FUNC(Py_ssize_t) PyUnicode_GetLength( PyObject *unicode );"
         ),
         (
             "Include/unicodeobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_FUNC(Py_UCS4) PyUnicode_ReadChar( PyObject *unicode, Py_ssize_t index );"
         ),
         (
             "Include/unicodeobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_FUNC(int) PyUnicode_WriteChar( PyObject *unicode, Py_ssize_t index, Py_UCS4 character );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) PyUnicode_Resize( PyObject **unicode, Py_ssize_t length );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_FromEncodedObject( PyObject *obj, const char *encoding, const char *errors );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_FromObject( PyObject *obj );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyUnicode_FromFormatV( const char *format, va_list vargs );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyUnicode_FromFormat( const char *format, ... );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(void) PyUnicode_InternInPlace(PyObject **);"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyUnicode_InternFromString( const char *u );"
         ),
         (
             "Include/unicodeobject.h",
             "defined(HAVE_WCHAR_H)",
             "PyAPI_FUNC(PyObject*) PyUnicode_FromWideChar( const wchar_t *w, Py_ssize_t size );"
         ),
         (
             "Include/unicodeobject.h",
             "defined(HAVE_WCHAR_H)",
             "PyAPI_FUNC(Py_ssize_t) PyUnicode_AsWideChar( PyObject *unicode, wchar_t *w, Py_ssize_t size );"
         ),
         (
             "Include/unicodeobject.h",
             "defined(HAVE_WCHAR_H)",
             "PyAPI_FUNC(wchar_t*) PyUnicode_AsWideCharString( PyObject *unicode, Py_ssize_t *size );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_FromOrdinal(int ordinal);"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(const char*) PyUnicode_GetDefaultEncoding(void);"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_Decode( const char *s, Py_ssize_t size, const char *encoding, const char *errors );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "Py_DEPRECATED(3.6) PyAPI_FUNC(PyObject*) PyUnicode_AsDecodedObject( PyObject *unicode, const char *encoding, const char *errors );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "Py_DEPRECATED(3.6) PyAPI_FUNC(PyObject*) PyUnicode_AsDecodedUnicode( PyObject *unicode, const char *encoding, const char *errors );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "Py_DEPRECATED(3.6) PyAPI_FUNC(PyObject*) PyUnicode_AsEncodedObject( PyObject *unicode, const char *encoding, const char *errors );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_AsEncodedString( PyObject *unicode, const char *encoding, const char *errors );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "Py_DEPRECATED(3.6) PyAPI_FUNC(PyObject*) PyUnicode_AsEncodedUnicode( PyObject *unicode, const char *encoding, const char *errors );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_BuildEncodingMap( PyObject* string );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_DecodeUTF7( const char *string, Py_ssize_t length, const char *errors );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_DecodeUTF7Stateful( const char *string, Py_ssize_t length, const char *errors, Py_ssize_t *consumed );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_DecodeUTF8( const char *string, Py_ssize_t length, const char *errors );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_DecodeUTF8Stateful( const char *string, Py_ssize_t length, const char *errors, Py_ssize_t *consumed );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_AsUTF8String( PyObject *unicode );"
         ),
         (
             "Include/unicodeobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030A0000)",
             "PyAPI_FUNC(const char *) PyUnicode_AsUTF8AndSize( PyObject *unicode, Py_ssize_t *size);"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_DecodeUTF32( const char *string, Py_ssize_t length, const char *errors, int *byteorder );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_DecodeUTF32Stateful( const char *string, Py_ssize_t length, const char *errors, int *byteorder, Py_ssize_t *consumed );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_AsUTF32String( PyObject *unicode );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_DecodeUTF16( const char *string, Py_ssize_t length, const char *errors, int *byteorder );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_DecodeUTF16Stateful( const char *string, Py_ssize_t length, const char *errors, int *byteorder, Py_ssize_t *consumed );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_AsUTF16String( PyObject *unicode );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_DecodeUnicodeEscape( const char *string, Py_ssize_t length, const char *errors );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_AsUnicodeEscapeString( PyObject *unicode );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_DecodeRawUnicodeEscape( const char *string, Py_ssize_t length, const char *errors );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_AsRawUnicodeEscapeString( PyObject *unicode );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_DecodeLatin1( const char *string, Py_ssize_t length, const char *errors );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_AsLatin1String( PyObject *unicode );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_DecodeASCII( const char *string, Py_ssize_t length, const char *errors );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_AsASCIIString( PyObject *unicode );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_DecodeCharmap( const char *string, Py_ssize_t length, PyObject *mapping, const char *errors );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_AsCharmapString( PyObject *unicode, PyObject *mapping );"
         ),
         (
             "Include/unicodeobject.h",
             "defined(MS_WINDOWS)",
             "PyAPI_FUNC(PyObject*) PyUnicode_DecodeMBCS( const char *string, Py_ssize_t length, const char *errors );"
         ),
         (
             "Include/unicodeobject.h",
             "defined(MS_WINDOWS)",
             "PyAPI_FUNC(PyObject*) PyUnicode_DecodeMBCSStateful( const char *string, Py_ssize_t length, const char *errors, Py_ssize_t *consumed );"
         ),
         (
             "Include/unicodeobject.h",
             "defined(MS_WINDOWS) && (!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_FUNC(PyObject*) PyUnicode_DecodeCodePageStateful( int code_page, const char *string, Py_ssize_t length, const char *errors, Py_ssize_t *consumed );"
         ),
         (
             "Include/unicodeobject.h",
             "defined(MS_WINDOWS)",
             "PyAPI_FUNC(PyObject*) PyUnicode_AsMBCSString( PyObject *unicode );"
         ),
         (
             "Include/unicodeobject.h",
             "defined(MS_WINDOWS) && (!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_FUNC(PyObject*) PyUnicode_EncodeCodePage( int code_page, PyObject *unicode, const char *errors );"
         ),
         (
             "Include/unicodeobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_FUNC(PyObject*) PyUnicode_DecodeLocaleAndSize( const char *str, Py_ssize_t len, const char *errors);"
         ),
         (
             "Include/unicodeobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_FUNC(PyObject*) PyUnicode_DecodeLocale( const char *str, const char *errors);"
         ),
         (
             "Include/unicodeobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_FUNC(PyObject*) PyUnicode_EncodeLocale( PyObject *unicode, const char *errors );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) PyUnicode_FSConverter(PyObject*, void*);"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) PyUnicode_FSDecoder(PyObject*, void*);"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_DecodeFSDefault( const char *s );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_DecodeFSDefaultAndSize( const char *s, Py_ssize_t size );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_EncodeFSDefault( PyObject *unicode );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_Concat( PyObject *left, PyObject *right );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(void) PyUnicode_Append( PyObject **pleft, PyObject *right );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(void) PyUnicode_AppendAndDel( PyObject **pleft, PyObject *right );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_Split( PyObject *s, PyObject *sep, Py_ssize_t maxsplit );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_Splitlines( PyObject *s, int keepends );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_Partition( PyObject *s, PyObject *sep );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_RPartition( PyObject *s, PyObject *sep );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_RSplit( PyObject *s, PyObject *sep, Py_ssize_t maxsplit );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyUnicode_Translate( PyObject *str, PyObject *table, const char *errors );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject*) PyUnicode_Join( PyObject *separator, PyObject *seq );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) PyUnicode_Tailmatch( PyObject *str, PyObject *substr, Py_ssize_t start, Py_ssize_t end, int direction );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) PyUnicode_Find( PyObject *str, PyObject *substr, Py_ssize_t start, Py_ssize_t end, int direction );"
         ),
         (
             "Include/unicodeobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000)",
             "PyAPI_FUNC(Py_ssize_t) PyUnicode_FindChar( PyObject *str, Py_UCS4 ch, Py_ssize_t start, Py_ssize_t end, int direction );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(Py_ssize_t) PyUnicode_Count( PyObject *str, PyObject *substr, Py_ssize_t start, Py_ssize_t end );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyUnicode_Replace( PyObject *str, PyObject *substr, PyObject *replstr, Py_ssize_t maxcount );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) PyUnicode_Compare( PyObject *left, PyObject *right );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) PyUnicode_CompareWithASCIIString( PyObject *left, const char *right );"
         ),
         (
             "Include/unicodeobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030D0000)",
             "PyAPI_FUNC(int) PyUnicode_EqualToUTF8(PyObject *, const char *);"
         ),
         (
             "Include/unicodeobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030D0000)",
             "PyAPI_FUNC(int) PyUnicode_EqualToUTF8AndSize(PyObject *, const char *, Py_ssize_t);"
         ),
         (
             "Include/unicodeobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030e0000)",
             "PyAPI_FUNC(int) PyUnicode_Equal(PyObject *str1, PyObject *str2);"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyUnicode_RichCompare( PyObject *left, PyObject *right, int op );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyUnicode_Format( PyObject *format, PyObject *args );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) PyUnicode_Contains( PyObject *container, PyObject *element );"
         ),
         (
             "Include/unicodeobject.h",
             "",
             "PyAPI_FUNC(int) PyUnicode_IsIdentifier(PyObject *s);"
         ),
         (
             "Include/warnings.h",
             "",
             "PyAPI_FUNC(int) PyErr_WarnEx( PyObject *category, const char *message, Py_ssize_t stack_level);"
         ),
         (
             "Include/warnings.h",
             "",
             "PyAPI_FUNC(int) PyErr_WarnFormat( PyObject *category, Py_ssize_t stack_level, const char *format, ...);"
         ),
         (
             "Include/warnings.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03060000)",
             "PyAPI_FUNC(int) PyErr_ResourceWarning( PyObject *source, Py_ssize_t stack_level, const char *format, ...);"
         ),
         (
             "Include/warnings.h",
             "",
             "PyAPI_FUNC(int) PyErr_WarnExplicit( PyObject *category, const char *message, const char *filename, int lineno, const char *module, PyObject *registry);"
         ),
         (
             "Include/weakrefobject.h",
             "",
             "PyAPI_DATA(PyTypeObject) _PyWeakref_RefType;"
         ),
         (
             "Include/weakrefobject.h",
             "",
             "PyAPI_DATA(PyTypeObject) _PyWeakref_ProxyType;"
         ),
         (
             "Include/weakrefobject.h",
             "",
             "PyAPI_DATA(PyTypeObject) _PyWeakref_CallableProxyType;"
         ),
         (
             "Include/weakrefobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyWeakref_NewRef(PyObject *ob, PyObject *callback);"
         ),
         (
             "Include/weakrefobject.h",
             "",
             "PyAPI_FUNC(PyObject *) PyWeakref_NewProxy(PyObject *ob, PyObject *callback);"
         ),
         (
             "Include/weakrefobject.h",
             "",
             "Py_DEPRECATED(3.13) PyAPI_FUNC(PyObject *) PyWeakref_GetObject(PyObject *ref);"
         ),
         (
             "Include/weakrefobject.h",
             "(!defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030D0000)",
             "PyAPI_FUNC(int) PyWeakref_GetRef(PyObject *ref, PyObject **pobj);"
         )
     ],
     CONDITIONAL_STRUCTS: list[tuple[str, str, str, list[str]]] = [
         (
             "Include/object.h",
             "!defined(Py_GIL_DISABLED)",
             "struct _object",
             [
                 "",
                 "#if (defined(__GNUC__) || defined(__clang__)) \\",
                 "        && !(defined __STDC_VERSION__ && __STDC_VERSION__ >= 201112L)",
                 "    // On C99 and older, anonymous union is a GCC and clang extension",
                 "    __extension__",
                 "#endif",
                 "#ifdef _MSC_VER",
                 "    // Ignore MSC warning C4201: \"nonstandard extension used:",
                 "    // nameless struct/union\"",
                 "    __pragma(warning(push))",
                 "    __pragma(warning(disable: 4201))",
                 "#endif",
                 "    union {",
                 "#if SIZEOF_VOID_P > 4",
                 "        PY_INT64_T ob_refcnt_full; /* This field is needed for efficient initialization with Clang on ARM */",
                 "        struct {",
                 "#  if PY_BIG_ENDIAN",
                 "            uint16_t ob_flags;",
                 "            uint16_t ob_overflow;",
                 "            uint32_t ob_refcnt;",
                 "#  else",
                 "            uint32_t ob_refcnt;",
                 "            uint16_t ob_overflow;",
                 "            uint16_t ob_flags;",
                 "#  endif",
                 "        };",
                 "#else",
                 "        Py_ssize_t ob_refcnt;",
                 "#endif",
                 "    };",
                 "#ifdef _MSC_VER",
                 "    __pragma(warning(pop))",
                 "#endif",
                 "",
                 "    PyTypeObject *ob_type;",
                 ""
             ]
         ),
         (
             "Include/object.h",
             "defined(Py_GIL_DISABLED)",
             "struct _object",
             [
                 "",
                 "    // ob_tid stores the thread id (or zero). It is also used by the GC and the",
                 "    // trashcan mechanism as a linked list pointer and by the GC to store the",
                 "    // computed \"gc_refs\" refcount.",
                 "    uintptr_t ob_tid;",
                 "    uint16_t ob_flags;",
                 "    PyMutex ob_mutex;           // per-object lock",
                 "    uint8_t ob_gc_bits;         // gc-related state",
                 "    uint32_t ob_ref_local;      // local reference count",
                 "    Py_ssize_t ob_ref_shared;   // shared (atomic) reference count",
                 "    PyTypeObject *ob_type;",
                 ""
             ]
         ),
         (
             "Include/cpython/weakrefobject.h",
             "",
             "struct _PyWeakReference",
             [
                 "",
                 "    PyObject_HEAD",
                 "",
                 "    /* The object to which this is a weak reference, or Py_None if none.",
                 "     * Note that this is a stealth reference:  wr_object's refcount is",
                 "     * not incremented to reflect this pointer.",
                 "     */",
                 "    PyObject *wr_object;",
                 "",
                 "    /* A callable to invoke when wr_object dies, or NULL if none. */",
                 "    PyObject *wr_callback;",
                 "",
                 "    /* A cache for wr_object's hash code.  As usual for hashes, this is -1",
                 "     * if the hash code isn't known yet.",
                 "     */",
                 "    Py_hash_t hash;",
                 "",
                 "    /* If wr_object is weakly referenced, wr_object has a doubly-linked NULL-",
                 "     * terminated list of weak references to it.  These are the list pointers.",
                 "     * If wr_object goes away, wr_object is set to Py_None, and these pointers",
                 "     * have no meaning then.",
                 "     */",
                 "    PyWeakReference *wr_prev;",
                 "    PyWeakReference *wr_next;",
                 "    vectorcallfunc vectorcall;",
                 "",
                 "#ifdef Py_GIL_DISABLED",
                 "    /* Pointer to the lock used when clearing in free-threaded builds.",
                 "     * Normally this can be derived from wr_object, but in some cases we need",
                 "     * to lock after wr_object has been set to Py_None.",
                 "     */",
                 "    PyMutex *weakrefs_lock;",
                 "#endif",
                 ""
             ]
         ),
         (
             "Include/internal/pycore_moduleobject.h",
             "",
             "PyModuleObject",
             [
                 "",
                 "    PyObject_HEAD",
                 "    PyObject *md_dict;",
                 "    PyModuleDef *md_def;",
                 "    void *md_state;",
                 "    PyObject *md_weaklist;",
                 "    // for logging purposes after md_dict is cleared",
                 "    PyObject *md_name;",
                 "#ifdef Py_GIL_DISABLED",
                 "    void *md_gil;",
                 "#endif",
                 ""
             ]
         ),
         (
             "Include/cpython/object.h",
             "",
             "PyHeapTypeObject",
             [
                 "",
                 "    /* Note: there's a dependency on the order of these members",
                 "       in slotptr() in typeobject.c . */",
                 "    PyTypeObject ht_type;",
                 "    PyAsyncMethods as_async;",
                 "    PyNumberMethods as_number;",
                 "    PyMappingMethods as_mapping;",
                 "    PySequenceMethods as_sequence; /* as_sequence comes after as_mapping,",
                 "                                      so that the mapping wins when both",
                 "                                      the mapping and the sequence define",
                 "                                      a given operator (e.g. __getitem__).",
                 "                                      see add_operators() in typeobject.c . */",
                 "    PyBufferProcs as_buffer;",
                 "    PyObject *ht_name, *ht_slots, *ht_qualname;",
                 "    struct _dictkeysobject *ht_cached_keys;",
                 "    PyObject *ht_module;",
                 "    char *_ht_tpname;  // Storage for \"tp_name\"; see PyType_FromModuleAndSpec",
                 "    void *ht_token;  // Storage for the \"Py_tp_token\" slot",
                 "    struct _specialization_cache _spec_cache; // For use by the specializer.",
                 "#ifdef Py_GIL_DISABLED",
                 "    Py_ssize_t unique_id;  // ID used for per-thread refcounting",
                 "#endif",
                 "    /* here are optional user slots, followed by the members. */",
                 ""
             ]
         ),
         (
             "Include/internal/pycore_interp_structs.h",
             "",
             "struct type_cache_entry",
             [
                 "",
                 "    unsigned int version;  // initialized from type->tp_version_tag",
                 "#ifdef Py_GIL_DISABLED",
                 "   _PySeqLock sequence;",
                 "#endif",
                 "    PyObject *name;        // reference to exactly a str or None",
                 "    PyObject *value;       // borrowed reference or NULL",
                 ""
             ]
         ),
         (
             "Include/cpython/pyerrors.h",
             "",
             "PyOSErrorObject",
             [
                 "",
                 "    PyException_HEAD",
                 "    PyObject *myerrno;",
                 "    PyObject *strerror;",
                 "    PyObject *filename;",
                 "    PyObject *filename2;",
                 "#ifdef MS_WINDOWS",
                 "    PyObject *winerror;",
                 "#endif",
                 "    Py_ssize_t written;   /* only for BlockingIOError, -1 otherwise */",
                 ""
             ]
         ),
         (
             "Include/internal/pycore_context.h",
             "",
             "struct _pycontextvarobject",
             [
                 "",
                 "    PyObject_HEAD",
                 "    PyObject *var_name;",
                 "    PyObject *var_default;",
                 "#ifndef Py_GIL_DISABLED",
                 "    PyObject *var_cached;",
                 "    uint64_t var_cached_tsid;",
                 "    uint64_t var_cached_tsver;",
                 "#endif",
                 "    Py_hash_t var_hash;",
                 ""
             ]
         ),
         (
             "Include/cpython/initconfig.h",
             "!defined(Py_LIMITED_API)",
             "struct PyPreConfig",
             [
                 "",
                 "    int _config_init;     /* _PyConfigInitEnum value */",
                 "",
                 "    /* Parse Py_PreInitializeFromBytesArgs() arguments?",
                 "       See PyConfig.parse_argv */",
                 "    int parse_argv;",
                 "",
                 "    /* If greater than 0, enable isolated mode: sys.path contains",
                 "       neither the script's directory nor the user's site-packages directory.",
                 "",
                 "       Set to 1 by the -I command line option. If set to -1 (default), inherit",
                 "       Py_IsolatedFlag value. */",
                 "    int isolated;",
                 "",
                 "    /* If greater than 0: use environment variables.",
                 "       Set to 0 by -E command line option. If set to -1 (default), it is",
                 "       set to !Py_IgnoreEnvironmentFlag. */",
                 "    int use_environment;",
                 "",
                 "    /* Set the LC_CTYPE locale to the user preferred locale? If equals to 0,",
                 "       set coerce_c_locale and coerce_c_locale_warn to 0. */",
                 "    int configure_locale;",
                 "",
                 "    /* Coerce the LC_CTYPE locale if it's equal to \"C\"? (PEP 538)",
                 "",
                 "       Set to 0 by PYTHONCOERCECLOCALE=0. Set to 1 by PYTHONCOERCECLOCALE=1.",
                 "       Set to 2 if the user preferred LC_CTYPE locale is \"C\".",
                 "",
                 "       If it is equal to 1, LC_CTYPE locale is read to decide if it should be",
                 "       coerced or not (ex: PYTHONCOERCECLOCALE=1). Internally, it is set to 2",
                 "       if the LC_CTYPE locale must be coerced.",
                 "",
                 "       Disable by default (set to 0). Set it to -1 to let Python decide if it",
                 "       should be enabled or not. */",
                 "    int coerce_c_locale;",
                 "",
                 "    /* Emit a warning if the LC_CTYPE locale is coerced?",
                 "",
                 "       Set to 1 by PYTHONCOERCECLOCALE=warn.",
                 "",
                 "       Disable by default (set to 0). Set it to -1 to let Python decide if it",
                 "       should be enabled or not. */",
                 "    int coerce_c_locale_warn;",
                 "",
                 "#ifdef MS_WINDOWS",
                 "    /* If greater than 1, use the \"mbcs\" encoding instead of the UTF-8",
                 "       encoding for the filesystem encoding.",
                 "",
                 "       Set to 1 if the PYTHONLEGACYWINDOWSFSENCODING environment variable is",
                 "       set to a non-empty string. If set to -1 (default), inherit",
                 "       Py_LegacyWindowsFSEncodingFlag value.",
                 "",
                 "       See PEP 529 for more details. */",
                 "    int legacy_windows_fs_encoding;",
                 "#endif",
                 "",
                 "    /* Enable UTF-8 mode? (PEP 540)",
                 "",
                 "       Disabled by default (equals to 0).",
                 "",
                 "       Set to 1 by \"-X utf8\" and \"-X utf8=1\" command line options.",
                 "       Set to 1 by PYTHONUTF8=1 environment variable.",
                 "",
                 "       Set to 0 by \"-X utf8=0\" and PYTHONUTF8=0.",
                 "",
                 "       If equals to -1, it is set to 1 if the LC_CTYPE locale is \"C\" or",
                 "       \"POSIX\", otherwise it is set to 0. Inherit Py_UTF8Mode value value. */",
                 "    int utf8_mode;",
                 "",
                 "    /* If non-zero, enable the Python Development Mode.",
                 "",
                 "       Set to 1 by the -X dev command line option. Set by the PYTHONDEVMODE",
                 "       environment variable. */",
                 "    int dev_mode;",
                 "",
                 "    /* Memory allocator: PYTHONMALLOC env var.",
                 "       See PyMemAllocatorName for valid values. */",
                 "    int allocator;",
                 ""
             ]
         )
     ];
