/* CPython value/slot operations shared by native Jac standard-library modules.
 * The calling native function holds the GIL. Handles are borrowed on input;
 * object results are new references. Algorithms belong in runtime/python/. */
#include <Python.h>
#include <errno.h>
#include <stdint.h>

/* libpython is built with hidden visibility, so only marked symbols reach a
 * native library that dlopens into this runtime. These entry points ARE that
 * boundary -- a separately built native unit calls them -- so export them. */
#pragma GCC visibility push(default)


void *jacpy_sequence_slot(PyObject *handle) {
    PyTypeObject *type = Py_TYPE(handle);
    if (type->tp_as_sequence && type->tp_as_sequence->sq_item)
        return type->tp_as_sequence->sq_item;
    PyErr_Format(PyExc_TypeError,
        type->tp_as_mapping && type->tp_as_mapping->mp_subscript
            ? "%.200s is not a sequence"
            : "'%.200s' object does not support indexing", type->tp_name);
    return NULL;
}
int64_t jacpy_less(PyObject *left, PyObject *right) {
    return PyObject_RichCompareBool(left, right, Py_LT);
}
int64_t jacpy_recursion_enter(const char *context) {
    /* Unlike most CPython status APIs this may return positive on failure. */
    return Py_EnterRecursiveCall(context) ? -1 : 0;
}

int64_t jacpy_list_size(PyObject *handle) { return PyList_GET_SIZE(handle); }
int64_t jacpy_list_delete(PyObject *handle, int64_t start, int64_t end) {
    return PyList_SetSlice(handle, (Py_ssize_t)start, (Py_ssize_t)end, NULL);
}
/* Exchange transfers the slot's reference to the caller; it cannot invoke a
 * finalizer while a native caller is still adjusting its container. */
PyObject *jacpy_list_exchange(PyObject *handle, int64_t index, PyObject *value) {
    PyObject *old = PyList_GetItem(handle, (Py_ssize_t)index);
    if (!old) return NULL;
    PyList_SET_ITEM(handle, index, Py_NewRef(value));
    return old;
}
void jacpy_list_swap(PyObject *handle, int64_t left, int64_t right) {
    PyObject *a = PyList_GET_ITEM(handle, left);
    PyObject *b = PyList_GET_ITEM(handle, right);
    PyList_SET_ITEM(handle, left, b);
    PyList_SET_ITEM(handle, right, a);
}

void *jacpy_comparison_slot(PyObject *handle) {
    return Py_TYPE(handle)->tp_richcompare;
}
int64_t jacpy_same_type(PyObject *left, PyObject *right) {
    return Py_TYPE(left) == Py_TYPE(right);
}

#include "internal/pycore_long.h"
#include "internal/pycore_object.h"
#include "internal/pycore_pylifecycle.h"
#include <unistd.h>

int64_t jacpy_is_long(PyObject *handle) { return PyLong_Check(handle); }
PyObject *jacpy_long_absolute(PyObject *handle) {
    return PyLong_Type.tp_as_number->nb_absolute(handle);
}
PyObject *jacpy_hash_unsigned(PyObject *handle) {
    Py_hash_t value = PyObject_Hash(handle);
    return value == -1 ? NULL : PyLong_FromSize_t((size_t)value);
}
PyObject *jacpy_long_bytes(PyObject *handle, int64_t size) {
    PyObject *result = PyBytes_FromStringAndSize(NULL, size);
    if (!result) return NULL;
    if (_PyLong_AsByteArray((PyLongObject *)handle,
            (unsigned char *)PyBytes_AS_STRING(result), size, 1, 0, 1) < 0) {
        Py_DECREF(result);
        return NULL;
    }
    return result;
}
PyObject *jacpy_long_from_bytes(PyObject *handle) {
    return _PyLong_FromByteArray((const unsigned char *)PyBytes_AS_STRING(handle),
                                      PyBytes_GET_SIZE(handle), 1, 0);
}
PyObject *jacpy_entropy(int64_t size) {
    PyObject *result = PyBytes_FromStringAndSize(NULL, size);
    if (!result) return NULL;
    if (_PyOS_URandomNonblock(PyBytes_AS_STRING(result), size) < 0) {
        Py_DECREF(result);
        return NULL;
    }
    return result;
}
int64_t jacpy_wall_time(void) {
    PyTime_t value;
    return PyTime_Time(&value) < 0 ? -1 : value;
}
int64_t jacpy_monotonic_time(void) {
    PyTime_t value;
    return PyTime_Monotonic(&value) < 0 ? -1 : value;
}
int64_t jacpy_process_id(void) { return getpid(); }
int64_t jacpy_is_tuple(PyObject *handle) { return PyTuple_Check(handle); }
PyObject *jacpy_tuple_item(PyObject *handle, int64_t index) {
    return Py_XNewRef(PyTuple_GetItem(handle, index));
}
int64_t jacpy_tuple_set_owned(PyObject *handle, int64_t index, PyObject *value) {
    if (!value) return -1;
    return PyTuple_SetItem(handle, index, value);
}

/* Argument converters keep an exported buffer alive through argument parsing
 * and the native call. This preserves resize guards and callback ordering. */
static int jacpy_binary_buffer(PyObject *value, void *output) {
    Py_buffer *view = output;
    if (!value) { PyBuffer_Release(view); return 1; }
    if (PyObject_GetBuffer(value, view, PyBUF_SIMPLE) < 0) return 0;
    return Py_CLEANUP_SUPPORTED;
}
static int jacpy_ascii_buffer(PyObject *value, void *output) {
    Py_buffer *view = output;
    if (!value) { PyBuffer_Release(view); return 1; }
    if (PyUnicode_Check(value)) {
        if (!PyUnicode_IS_ASCII(value)) {
            PyErr_SetString(PyExc_ValueError, "string argument should contain only ASCII characters");
            return 0;
        }
        if (PyBuffer_FillInfo(view, value, PyUnicode_DATA(value),
                             PyUnicode_GET_LENGTH(value), 1, PyBUF_SIMPLE) < 0) return 0;
    } else if (PyObject_GetBuffer(value, view, PyBUF_SIMPLE) < 0) {
        if (!PyObject_CheckBuffer(value))
            PyErr_Format(PyExc_TypeError, "argument should be bytes, buffer or ASCII string, not '%.100s'", Py_TYPE(value)->tp_name);
        return 0;
    }
    return Py_CLEANUP_SUPPORTED;
}
/* Py_buffer(accept={str, buffer}): a str lends its UTF-8 encoding. */
static int jacpy_text_buffer(PyObject *value, Py_buffer *view) {
    if (!PyUnicode_Check(value)) return PyObject_GetBuffer(value, view, PyBUF_SIMPLE) == 0;
    Py_ssize_t size;
    const char *data = PyUnicode_AsUTF8AndSize(value, &size);
    return data && PyBuffer_FillInfo(view, value, (void *)data, size, 1, PyBUF_SIMPLE) == 0;
}
PyObject *jacpy_buffer_bytes(const Py_buffer *view) {
    if (PyBytes_CheckExact(view->obj) && view->buf == PyBytes_AS_STRING(view->obj)
        && view->len == PyBytes_GET_SIZE(view->obj)) return Py_NewRef(view->obj);
    return PyBytes_FromStringAndSize(view->buf, view->len);
}
/* kind: 0 any buffer, 1 buffer or ASCII str, 2 buffer or str (UTF-8). */
Py_buffer *jacpy_buffer_acquire(PyObject *value, int64_t kind) {
    Py_buffer *view = PyMem_Calloc(1, sizeof(*view));
    if (!view) { PyErr_NoMemory(); return NULL; }
    int ok = kind == 2 ? jacpy_text_buffer(value, view)
           : kind == 1 ? jacpy_ascii_buffer(value, view)
                       : jacpy_binary_buffer(value, view);
    if (!ok) { PyMem_Free(view); return NULL; }
    return view;
}
void jacpy_buffer_release(Py_buffer *value) {
    if (!value) return;
    Py_buffer *view = value;
    PyBuffer_Release(view);
    PyMem_Free(view);
}
int64_t jacpy_unicode_ascii(PyObject *value) { return PyUnicode_IS_ASCII(value); }
void jacpy_set_exception(PyObject *type, const char *message, int64_t size) {
    PyObject *text = PyUnicode_DecodeUTF8(message, size, "surrogatepass");
    if (text) { PyErr_SetObject(type, text); Py_DECREF(text); }
}

PyObject *jacpy_power(PyObject *a, PyObject *b, int64_t inplace) {
    return inplace ? PyNumber_InPlacePower(a, b, Py_None)
                          : PyNumber_Power(a, b, Py_None);
}
int64_t jacpy_is_unicode(PyObject *a) { return PyUnicode_Check(a); }
PyObject *jacpy_unicode_split(PyObject *a, PyObject *sep) { return PyUnicode_Split(a, sep, -1); }
int64_t jacpy_dict_size(PyObject *a) { return a ? PyDict_Size(a) : 0; }
#include <openssl/crypto.h>
int64_t jacpy_crypto_compare(const void *a, const void *b, int64_t size) {
    return CRYPTO_memcmp(a, b, size);
}

/* Portable CPython wait primitives. Queue policy stays in Jac; only the wait
 * releases the GIL, and it restores it before touching any native state. */
#include "internal/pycore_time.h"
void *jacpy_lock_new(void) {
    PyThread_type_lock lock = PyThread_allocate_lock();
    if (!lock) { PyErr_NoMemory(); return NULL; }
    PyThread_acquire_lock(lock, WAIT_LOCK);
    return lock;
}
void jacpy_lock_free(void *handle) {
    PyThread_type_lock lock = handle;
    PyThread_acquire_lock(lock, NOWAIT_LOCK);
    PyThread_release_lock(lock);
    PyThread_free_lock(lock);
}
int64_t jacpy_lock_wait(void *handle, int64_t timeout_ns) {
    PyTime_t timeout_us = timeout_ns < 0 ? -1 : _PyTime_AsMicroseconds(timeout_ns, _PyTime_ROUND_CEILING);
    PyLockStatus status;
    Py_BEGIN_ALLOW_THREADS
    status = PyThread_acquire_lock_timed(handle, timeout_us, 1);
    Py_END_ALLOW_THREADS
    return status == PY_LOCK_ACQUIRED ? 1 : (status == PY_LOCK_INTR ? -1 : 0);
}
int64_t jacpy_timeout_ns(PyObject *value) {
    PyTime_t timeout;
    if (_PyTime_FromSecondsObject(&timeout, value, _PyTime_ROUND_CEILING) < 0) return -1;
    return timeout;
}

/* Unicode builders and exact container operations used by native serializers. */
PyUnicodeWriter *jacpy_writer_new(void) { return PyUnicodeWriter_Create(0); }
int64_t jacpy_unicode_size(PyObject *text) { return PyUnicode_GET_LENGTH(text); }
PyObject *jacpy_unicode_decode_bytes(PyObject *value, const char *encoding) { return PyUnicode_FromEncodedObject(value, encoding, "strict"); }
PyObject *jacpy_dict_default(PyObject *dictionary, PyObject *key, PyObject *value) {
    PyObject *result;
    return PyDict_SetDefaultRef(dictionary, key, value, &result) < 0 ? NULL : result;
}
int64_t jacpy_is_bool(PyObject *value) { return PyBool_Check(value); }
int64_t jacpy_is_float(PyObject *value) { return PyFloat_Check(value); }
int64_t jacpy_is_dict(PyObject *value) { return PyDict_Check(value); }
int64_t jacpy_is_exact_dict(PyObject *value) { return PyDict_CheckExact(value); }
PyObject *jacpy_long_repr(PyObject *value) { return PyLong_Type.tp_repr(value); }
PyObject *jacpy_float_repr(PyObject *value) { return PyFloat_Type.tp_repr(value); }
PyObject *jacpy_type_name(PyObject *value) { return PyUnicode_FromString(Py_TYPE(value)->tp_name); }
PyObject *jacpy_qualified_type_name(PyObject *value) { return PyType_GetFullyQualifiedName(Py_TYPE(value)); }
int64_t jacpy_fast_size(PyObject *value) { return PySequence_Fast_GET_SIZE(value); }
PyObject *jacpy_fast_item(PyObject *value, int64_t index) { return Py_NewRef(PySequence_Fast_GET_ITEM(value, index)); }

/* Protocol primitives shared by native streaming and container modules. */
int64_t jacpy_is_exact_long(PyObject *value) { return PyLong_CheckExact(value); }
int64_t jacpy_type_check(PyObject *value, PyObject *type) { return PyObject_TypeCheck(value, (PyTypeObject *)type); }
PyObject *jacpy_dict_get(PyObject *dictionary, PyObject *key) {
    PyObject *value;
    return PyDict_GetItemRef(dictionary, key, &value) < 0 ? NULL : value;
}
int64_t jacpy_dict_pop_discard(PyObject *dictionary, PyObject *key) { return PyDict_Pop(dictionary, key, NULL); }

/* Memory and numeric representation primitives, shared by binary layouts. */
int64_t jacpy_native_size(int64_t kind, int64_t alignment) {
#define SIZE_CASE(code, type) case code: return alignment ? _Alignof(type) : sizeof(type)
    switch (kind) {
        SIZE_CASE(0, char); SIZE_CASE(1, short); SIZE_CASE(2, int);
        SIZE_CASE(3, long); SIZE_CASE(4, long long); SIZE_CASE(5, size_t);
        SIZE_CASE(6, void *); SIZE_CASE(7, _Bool); SIZE_CASE(8, float); SIZE_CASE(9, double);
        default: return 0;
    }
#undef SIZE_CASE
}
int64_t jacpy_native_little_endian(void) { uint16_t value = 1; return *(unsigned char *)&value; }
/* The target ABI's CHAR_MAX: 255 where char is unsigned (Linux aarch64). */
int64_t jacpy_char_max(void) { return CHAR_MAX; }
void jacpy_memory_zero(void *address, int64_t size) { memset(address, 0, (size_t)size); }
void jacpy_memory_copy(void *target, void *source, int64_t size) { memcpy(target, source, (size_t)size); }
void jacpy_memory_move(void *target, void *source, int64_t size) { memmove(target, source, (size_t)size); }
PyObject *jacpy_bytearray_new(int64_t size) { return PyByteArray_FromStringAndSize(NULL, size); }
int64_t jacpy_bytearray_memory(PyObject *value) { return PyByteArray_Type.tp_basicsize + ((PyByteArrayObject *)value)->ob_alloc; }
uint64_t jacpy_float32_bits(double value) { float number = (float)value; uint32_t bits; memcpy(&bits, &number, sizeof(bits)); return bits; }
PyObject *jacpy_bytes_from_memory(const void *address, int64_t size) { return PyBytes_FromStringAndSize(address, size); }
int64_t jacpy_is_bytes(PyObject *value) { return PyBytes_Check(value); }
int64_t jacpy_is_bytearray(PyObject *value) { return PyByteArray_Check(value); }
void *jacpy_bytes_address(PyObject *value) { return (PyBytes_Check(value) ? PyBytes_AS_STRING(value) : PyByteArray_AS_STRING(value)); }
int64_t jacpy_bytes_length(PyObject *value) { return PyBytes_Check(value) ? PyBytes_GET_SIZE(value) : PyByteArray_GET_SIZE(value); }
/* Jac passes a bytes argument as its payload address; these copy a whole
 * payload across the boundary instead of one element per call. */
void jacpy_bytes_copy_to(PyObject *value, char *target, int64_t size) { memcpy(target, jacpy_bytes_address(value), (size_t)size); }
PyObject *jacpy_complex_value(PyObject *value) {
    Py_complex number = PyComplex_AsCComplex(value);
    if (PyErr_Occurred()) return NULL;
    return PyComplex_FromCComplex(number);
}
int64_t jacpy_float_pack(double value, void *address, int64_t size, int64_t little) {
    char *target = address;
    if (size == 2) return PyFloat_Pack2(value, target, (int)little);
    if (size == 4) return PyFloat_Pack4(value, target, (int)little);
    return PyFloat_Pack8(value, target, (int)little);
}
double jacpy_float_unpack(const void *address, int64_t size, int64_t little) {
    const char *source = address;
    if (size == 2) return PyFloat_Unpack2(source, (int)little);
    if (size == 4) return PyFloat_Unpack4(source, (int)little);
    return PyFloat_Unpack8(source, (int)little);
}
void jacpy_native_float_store(double value, void *address, int64_t size) {
    if (size == 4) { float number = (float)value; memcpy(address, &number, sizeof(number)); }
    else memcpy(address, &value, sizeof(value));
}



void jacpy_clear_errno(void) { errno = 0; }
int64_t jacpy_math_errno(void) { return errno == EDOM ? 1 : errno == ERANGE ? 2 : 0; }

/* The platform libm functions whose results the math modules pass on. Zig's
 * compiler-rt is a single object that also defines weak, hidden copies of
 * log, log2, log10, exp, exp2, sin, cos, tan and fma. A Mach-O link pulls
 * that object in for other builtins, and its copies then bind every call in
 * the image ahead of libSystem's: its log2 misreads subnormal inputs and its
 * fma drops the sign of a result that underflows to zero. CPython's math
 * module is a shared extension there and reaches libSystem, so darwin looks
 * the functions up by name in libSystem. Elsewhere the plain call reaches the
 * C library already. Exactly rounded functions (sqrt, fabs, floor, ceil,
 * fmod) have one correct result and are called directly. */
#ifdef __APPLE__
#include <dlfcn.h>
#include <pthread.h>
static struct {
    double (*log)(double);
    double (*log2)(double);
    double (*log10)(double);
    double (*exp)(double);
    double (*exp2)(double);
    double (*sin)(double);
    double (*cos)(double);
    double (*tan)(double);
    double (*fma)(double, double, double);
} jacpy_libm;
static pthread_once_t jacpy_libm_once = PTHREAD_ONCE_INIT;
static void *jacpy_libm_find(void *system, const char *name, void *fallback) {
    void *found = system ? dlsym(system, name) : NULL;
    return found ? found : fallback;
}
static void jacpy_libm_resolve(void) {
    void *system = dlopen("/usr/lib/libSystem.B.dylib", RTLD_LAZY | RTLD_NOLOAD);
    jacpy_libm.log = (double (*)(double))jacpy_libm_find(system, "log", (void *)log);
    jacpy_libm.log2 = (double (*)(double))jacpy_libm_find(system, "log2", (void *)log2);
    jacpy_libm.log10 = (double (*)(double))jacpy_libm_find(system, "log10", (void *)log10);
    jacpy_libm.exp = (double (*)(double))jacpy_libm_find(system, "exp", (void *)exp);
    jacpy_libm.exp2 = (double (*)(double))jacpy_libm_find(system, "exp2", (void *)exp2);
    jacpy_libm.sin = (double (*)(double))jacpy_libm_find(system, "sin", (void *)sin);
    jacpy_libm.cos = (double (*)(double))jacpy_libm_find(system, "cos", (void *)cos);
    jacpy_libm.tan = (double (*)(double))jacpy_libm_find(system, "tan", (void *)tan);
    jacpy_libm.fma = (double (*)(double, double, double))jacpy_libm_find(
        system, "fma", (void *)fma);
}
#define JACPY_LIBM(name) (pthread_once(&jacpy_libm_once, jacpy_libm_resolve), jacpy_libm.name)
#else
#define JACPY_LIBM(name) name
#endif
double jacpy_libm_log(double value) { return JACPY_LIBM(log)(value); }
double jacpy_libm_log2(double value) { return JACPY_LIBM(log2)(value); }
double jacpy_libm_log10(double value) { return JACPY_LIBM(log10)(value); }
double jacpy_libm_exp(double value) { return JACPY_LIBM(exp)(value); }
double jacpy_libm_exp2(double value) { return JACPY_LIBM(exp2)(value); }
double jacpy_libm_sin(double value) { return JACPY_LIBM(sin)(value); }
double jacpy_libm_cos(double value) { return JACPY_LIBM(cos)(value); }
double jacpy_libm_tan(double value) { return JACPY_LIBM(tan)(value); }
double jacpy_libm_fma(double x, double y, double z) { return JACPY_LIBM(fma)(x, y, z); }

PyObject *jacpy_dict_repr(PyObject *value) { return PyDict_Type.tp_repr(value); }


int64_t jacpy_long_sign(PyObject *value) {
    PyLongObject *integer = (PyLongObject *)value;
    return _PyLong_IsNegative(integer) ? -1 : _PyLong_IsZero(integer) ? 0 : 1;
}
PyObject *jacpy_long_shift(PyObject *value, int64_t count, int64_t left) {
    return left ? _PyLong_Lshift(value, count) : _PyLong_Rshift(value, count);
}

PyObject *jacpy_special_noargs(PyObject *value, const char *name) {
    PyObject *key=PyUnicode_InternFromString(name);
    if(!key) return NULL;
    PyObject *method=_PyObject_LookupSpecial(value,key); Py_DECREF(key);
    if(!method) return NULL;
    PyObject *result=PyObject_CallNoArgs(method); Py_DECREF(method); return result;
}
uint64_t jacpy_float_bits(double value) { uint64_t bits; memcpy(&bits,&value,sizeof(bits)); return bits; }
double jacpy_float_from_bits(uint64_t bits) { double value; memcpy(&value,&bits,sizeof(value)); return value; }


int64_t jacpy_is_exact_float(PyObject *value) { return PyFloat_CheckExact(value); }

int64_t jacpy_long_fits_i64(PyObject *value) { int overflow; (void)PyLong_AsLongLongAndOverflow(value,&overflow); return overflow == 0; }

/* Retained object primitives used by native callable and cache policies. */
PyObject *jacpy_call_two(PyObject *callable, PyObject *a, PyObject *b) {
    PyObject *args[] = {a, b};
    return PyObject_Vectorcall(callable, args, 2, NULL);
}
PyObject *jacpy_object_type(PyObject *value) { return Py_NewRef(Py_TYPE(value)); }
int64_t jacpy_is_exact_unicode(PyObject *value) { return PyUnicode_CheckExact(value); }
int64_t jacpy_is_exact_tuple(PyObject *value) { return PyTuple_CheckExact(value); }
int64_t jacpy_is_exact_list(PyObject *value) { return PyList_CheckExact(value); }

int64_t jacpy_tuple_unique(PyObject *value) { return Py_REFCNT(value) == 1; }
/* Exchange is valid only after the native caller has established exclusive
 * ownership. It returns the old reference without invoking a finalizer. */
PyObject *jacpy_tuple_exchange(PyObject *value, int64_t index, PyObject *item) {
    PyObject *tuple=value, *old=PyTuple_GET_ITEM(tuple,index);
    PyTuple_SET_ITEM(tuple,index,Py_NewRef(item));
    if(!PyObject_GC_IsTracked(tuple)) PyObject_GC_Track(tuple);
    return old;
}

/* Retained object primitives used by native wire protocols. */
PyObject *jacpy_long_signed_bytes(PyObject *value, int64_t size) {
    PyObject *result = PyBytes_FromStringAndSize(NULL, size);
    if (!result) return NULL;
    if (_PyLong_AsByteArray((PyLongObject *)value, (unsigned char *)PyBytes_AS_STRING(result), size, 1, 1, 1) < 0) {
        Py_DECREF(result); return NULL;
    }
    return result;
}
PyObject *jacpy_long_from_signed_bytes(PyObject *value) {
    return _PyLong_FromByteArray((const unsigned char *)PyBytes_AS_STRING(value), PyBytes_GET_SIZE(value), 1, 1);
}
PyObject *jacpy_bytes_decode(PyObject *value, const char *encoding, const char *errors) {
    return PyUnicode_Decode(PyBytes_AS_STRING(value), PyBytes_GET_SIZE(value), encoding, errors);
}
PyObject *jacpy_optional_attr(PyObject *value, const char *name) { PyObject *result = NULL; return PyObject_GetOptionalAttrString(value, name, &result) < 0 ? NULL : result; }
PyObject *jacpy_type_new(PyObject *type, PyObject *args, PyObject *kwargs) {
    if (!PyType_Check(type)) { PyErr_SetString(PyExc_TypeError, "NEWOBJ class argument must be a type"); return NULL; }
    if (!PyTuple_Check(args)) { PyErr_SetString(PyExc_TypeError, "NEWOBJ args argument must be a tuple"); return NULL; }
    if (kwargs && !PyDict_Check(kwargs)) { PyErr_SetString(PyExc_TypeError, "NEWOBJ_EX kwargs argument must be a dict"); return NULL; }
    PyTypeObject *cls = (PyTypeObject *)type;
    if (!cls->tp_new) { PyErr_SetString(PyExc_TypeError, "NEWOBJ class has no __new__"); return NULL; }
    return cls->tp_new(cls, args, kwargs);
}

PyObject *jacpy_set_new(PyObject *iterable, int64_t frozen) { return frozen ? PyFrozenSet_New(iterable) : PySet_New(iterable); }
int64_t jacpy_is_type(PyObject *value) { return PyType_Check(value); }
PyObject *jacpy_bytes_unescape(PyObject *value) { return PyBytes_DecodeEscape(PyBytes_AS_STRING(value), PyBytes_GET_SIZE(value), "strict", 0, NULL); }



PyObject *jacpy_mapping_optional_item(PyObject *mapping, PyObject *key) { PyObject *result = NULL; return PyMapping_GetOptionalItem(mapping, key, &result) < 0 ? NULL : result; }



void jacpy_exception_context(PyObject *error, PyObject *cause) { PyException_SetContext(error, Py_NewRef(cause)); }

PyObject *jacpy_unicode_intern(PyObject *value) { PyObject *result=Py_NewRef(value); PyUnicode_InternInPlace(&result); return result; }

/* General value conversion and interpreter services for native bindings. */
int64_t jacpy_is_slice(PyObject *value) { return PySlice_Check(value); }
int64_t jacpy_is_code(PyObject *value) { return PyCode_Check(value); }
typedef struct { int64_t start, stop, step, count, valid; } SliceBounds;
SliceBounds jacpy_slice_unpack(PyObject *value) {
    SliceBounds result = {0};
    Py_ssize_t start, stop, step;
    if (PySlice_Unpack(value, &start, &stop, &step) == 0)
        result = (SliceBounds){start, stop, step, 0, 1};
    return result;
}
SliceBounds jacpy_slice_adjust(int64_t length, SliceBounds bounds) {
    Py_ssize_t start = bounds.start, stop = bounds.stop;
    bounds.count = PySlice_AdjustIndices(length, &start, &stop, bounds.step);
    bounds.start = start; bounds.stop = stop;
    return bounds;
}
PyObject *jacpy_builtins(void) { return Py_NewRef(PyEval_GetBuiltins()); }
#pragma GCC visibility pop

/* A NUL-terminated string that C owns (a libc record field, an environment
 * entry), decoded with the filesystem encoding; NULL becomes None. */
PyObject *jacpy_fs_text(const void *text) {
    return text ? PyUnicode_DecodeFSDefault(text) : Py_NewRef(Py_None);
}

/* PyCFunctionObject fields, which only its object layout holds; borrowed. */
PyMethodDef *jacpy_cfunction_method(PyObject *function) { return ((PyCFunctionObject *)function)->m_ml; }
PyObject *jacpy_cfunction_self(PyObject *function) { return ((PyCFunctionObject *)function)->m_self; }
PyObject *jacpy_cfunction_module(PyObject *function) { return ((PyCFunctionObject *)function)->m_module; }

/* Struct sequence types need a field array that outlives the type, as the
 * static arrays of C modules do. Fields are "name\tdoc" lines. The
 * descriptor is intentionally never freed: the type may be shared by
 * interpreters and lives for the process. */
PyObject *jacpy_struct_sequence_type(const char *name, const char *doc,
                                     const char *fields, int64_t visible) {
    size_t count = 1;
    for (const char *c = fields; *c; c++) count += *c == '\n';
    char *names = strdup(fields);
    char *owned_name = strdup(name), *owned_doc = strdup(doc);
    PyStructSequence_Field *table = calloc(count + 1, sizeof(*table));
    PyStructSequence_Desc *desc = calloc(1, sizeof(*desc));
    if (!names || !owned_name || !owned_doc || !table || !desc) {
        free(names); free(owned_name); free(owned_doc); free(table); free(desc);
        return PyErr_NoMemory();
    }
    size_t index = 0;
    for (char *line = strtok(names, "\n"); line; line = strtok(NULL, "\n")) {
        char *tab = strchr(line, '\t');
        if (tab) *tab = '\0';
        table[index++] = (PyStructSequence_Field){line, tab && tab[1] ? tab + 1 : NULL};
    }
    *desc = (PyStructSequence_Desc){owned_name, *owned_doc ? owned_doc : NULL, table, (int)visible};
    return (PyObject *)PyStructSequence_NewType(desc);
}

/* The interpreter's typing types (TypeVar, ParamSpec, Generic, ...) are
 * interpreter-state fields, not data symbols. This is the run of
 * interp->cached_objects from generic_type on, in declaration order. */
#include "internal/pycore_interp.h"
#include "internal/pycore_pystate.h"
#define JACPY_TYPING_SLOT(field, index) \
    _Static_assert(offsetof(struct _Py_interp_cached_objects, field) \
        == offsetof(struct _Py_interp_cached_objects, generic_type) + (index) * sizeof(PyObject *), #field);
JACPY_TYPING_SLOT(typevar_type, 1) JACPY_TYPING_SLOT(typevartuple_type, 2)
JACPY_TYPING_SLOT(paramspec_type, 3) JACPY_TYPING_SLOT(paramspecargs_type, 4)
JACPY_TYPING_SLOT(paramspeckwargs_type, 5)
#undef JACPY_TYPING_SLOT
PyObject **jacpy_typing_types(void) {
    return (PyObject **)&_PyInterpreterState_GET()->cached_objects.generic_type;
}

/* Weak references hang off an object-layout list that only C can walk. */
#include "internal/pycore_weakref.h"
#include "internal/pycore_dict.h"
PyObject *jacpy_weakref_list(PyObject *object) {
    PyObject *result = PyList_New(0);
    if (result == NULL || !_PyType_SUPPORTS_WEAKREFS(Py_TYPE(object))) return result;
    LOCK_WEAKREFS(object);
    PyWeakReference *current = *(PyWeakReference **)_PyObject_GET_WEAKREFS_LISTPTR(object);
    while (current != NULL) {
        PyObject *item = (PyObject *)current;
        if (_Py_TryIncref(item)) {
            int failed = PyList_Append(result, item);
            Py_DECREF(item);
            if (failed) { UNLOCK_WEAKREFS(object); Py_DECREF(result); return NULL; }
        }
        current = current->wr_next;
    }
    UNLOCK_WEAKREFS(object);
    return result;
}
static int dead_weakref(PyObject *value, void *unused) {
    if (!PyWeakref_Check(value)) {
        PyErr_SetString(PyExc_TypeError, "not a weakref");
        return -1;
    }
    return _PyWeakref_IS_DEAD(value);
}
int64_t jacpy_remove_dead_weakref(PyObject *dictionary, PyObject *key) {
    return _PyDict_DelItemIf(dictionary, key, dead_weakref, NULL);
}

/* errno is a thread-local macro; read and write it through functions. */
int64_t jacpy_errno(void) { return errno; }
void jacpy_set_errno(int64_t value) { errno = (int)value; }

/* Directory iteration. struct dirent's layout and the opendir/readdir symbol
 * variants differ between C libraries and macOS architectures (x86_64 binds
 * $INODE64 versions), so both calls and the d_name field stay in C. */
#include <dirent.h>
void *jacpy_opendir(const char *path) { return opendir(path); }
const char *jacpy_readdir_name(void *directory) { struct dirent *entry = readdir((DIR *)directory); return entry ? entry->d_name : NULL; }
int32_t jacpy_dirfd(void *directory) { return dirfd((DIR *)directory); }
int32_t jacpy_closedir(void *directory) { return closedir((DIR *)directory); }

/* _PyInterpreterState_GetFinalizing() is static inline. */
int64_t jacpy_interpreter_finalizing(void) { return _PyInterpreterState_GetFinalizing(_PyInterpreterState_GET()) != NULL; }

/* PyLong_AsNativeBytes into a uint64_t, the way modules convert rlim_t and
 * similar unsigned C types: -1 on error, 1 when the value needs more than
 * eight bytes, 0 when it fits. */
int64_t jacpy_long_u64_checked(PyObject *value, uint64_t *out) {
    Py_ssize_t bytes = PyLong_AsNativeBytes(value, out, sizeof(*out),
        Py_ASNATIVEBYTES_NATIVE_ENDIAN | Py_ASNATIVEBYTES_UNSIGNED_BUFFER);
    if (bytes < 0) return -1;
    return bytes > (Py_ssize_t)sizeof(*out);
}

/* Argument Clinic's unsigned_long and unsigned_long_long converters (the
 * non-bitwise ones): __index__ is accepted, a negative value raises ValueError
 * and a wider one OverflowError naming the C type. 1 on success. */
#include "internal/pycore_long.h"
int64_t jacpy_unsigned_converter(PyObject *value, uint64_t *out, int64_t long_long) {
    if (long_long) return _PyLong_UnsignedLongLong_Converter(value, out);
    unsigned long result = 0;
    int ok = _PyLong_UnsignedLong_Converter(value, &result);
    *out = result;
    return ok;
}

/* The address an int denotes, as struct's 'P' format packs it. */
uint64_t jacpy_long_address(PyObject *value) { return (uint64_t)(uintptr_t)PyLong_AsVoidPtr(value); }

/* HACL*'s vectorized BLAKE2 runs only where configure compiled it and the CPU
 * has the instructions; the CPUID probe is an intrinsic Jac cannot express.
 * Bit 0: SSE through SSE4.2 and CMOV (Blake2s SIMD128); bit 1: AVX and AVX2
 * (Blake2b SIMD256). Both stay 0 off x86-64, as in blake2module.c. */
#if defined(__x86_64__) && defined(__GNUC__)
#include <cpuid.h>
#endif
int64_t jacpy_hacl_simd_features(void) {
    int64_t features = 0;
#if defined(__x86_64__) && defined(__GNUC__)
    unsigned int eax1 = 0, ebx1 = 0, ecx1 = 0, edx1 = 0;
    unsigned int eax7 = 0, ebx7 = 0, ecx7 = 0, edx7 = 0;
    __cpuid_count(1, 0, eax1, ebx1, ecx1, edx1);
    __cpuid_count(7, 0, eax7, ebx7, ecx7, edx7);
    (void)eax1; (void)ebx1; (void)ecx1; (void)edx1;
    (void)eax7; (void)ebx7; (void)ecx7; (void)edx7;
#ifdef _Py_HACL_CAN_COMPILE_VEC128
    if ((edx1 & (1u << 25)) && (edx1 & (1u << 26)) && (ecx1 & (1u << 0))
        && (ecx1 & (1u << 19)) && (ecx1 & (1u << 20)) && (edx1 & (1u << 15)))
        features |= 1;
#endif
#ifdef _Py_HACL_CAN_COMPILE_VEC256
    if ((ecx1 & (1u << 28)) && (ebx7 & (1u << 5))) features |= 2;
#endif
#endif
    return features;
}
