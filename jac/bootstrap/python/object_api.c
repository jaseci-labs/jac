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
/* A tuple's item array (PyTupleObject.ob_item): the generated argument glue
 * binds a call's positional tuple in place. */
PyObject **jacpy_tuple_items(PyObject *handle) { return ((PyTupleObject *)handle)->ob_item; }
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
int64_t jacpy_unicode_kind(PyObject *text) { return PyUnicode_KIND(text); }
void *jacpy_unicode_data(PyObject *text) { return PyUnicode_DATA(text); }
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
/* The same for a Jac bytes argument, which arrives as its payload address. */
PyObject *jacpy_bytes_from_payload(const char *data, int64_t size) { return PyBytes_FromStringAndSize(data, size); }
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
 * the functions up by name in libSystem. A static Linux link can resolve the
 * plain call to the same copies whenever compiler-rt precedes libm, so Linux
 * looks them up in libm.so.6 the same way. Exactly rounded functions (sqrt,
 * fabs, floor, ceil, fmod) have one correct result and are called directly. */
#if defined(__APPLE__)
#define JACPY_LIBM_IMAGE "/usr/lib/libSystem.B.dylib"
#elif defined(__linux__)
#define JACPY_LIBM_IMAGE "libm.so.6"
#endif
#ifdef JACPY_LIBM_IMAGE
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
    void *system = dlopen(JACPY_LIBM_IMAGE, RTLD_LAZY | RTLD_NOLOAD);
    if (!system) {
        system = dlopen(JACPY_LIBM_IMAGE, RTLD_LAZY);
    }
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
    char *rest = NULL;
    /* strtok_r: interpreters with their own GIL create these types at once. */
    for (char *line = strtok_r(names, "\n", &rest); line; line = strtok_r(NULL, "\n", &rest)) {
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

/* The open_code hook and its data are _PyRuntime fields, whose layout
 * differs between builds. */
#include "internal/pycore_runtime.h"
void **jacpy_open_code_hook(void) { return (void **)&_PyRuntime.open_code_hook; }
void **jacpy_open_code_userdata(void) { return &_PyRuntime.open_code_userdata; }

/* The descriptor of stdin (0), stdout (1) or stderr (2): the stdio streams are
 * macros or differently named globals across C libraries. */
int32_t jacpy_stdio_fileno(int32_t stream) { return fileno(stream == 2 ? stderr : stream == 1 ? stdout : stdin); }

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

/* _asyncio's running loop and task are _PyThreadStateImpl fields, and its
 * tasks are linked into lists headed there and in PyInterpreterState;
 * visiting other threads needs the runtime's thread-state iteration with the
 * world stopped. The Jac port links a task through the llist_node at
 * `node_offset` of its TaskObj. */
#include "internal/pycore_llist.h"
#include "internal/pycore_tstate.h"
#include "internal/pycore_list.h"
#include "internal/pycore_ceval.h"
PyObject **jacpy_asyncio_running_loop(void) { return &((_PyThreadStateImpl *)_PyThreadState_GET())->asyncio_running_loop; }
PyObject **jacpy_asyncio_running_task(void) { return &((_PyThreadStateImpl *)_PyThreadState_GET())->asyncio_running_task; }
void *jacpy_asyncio_tasks_head(void) { return &((_PyThreadStateImpl *)_PyThreadState_GET())->asyncio_tasks_head; }
/* current_task(loop) for a loop another thread runs: a new reference to its
 * running task, or to None. */
PyObject *jacpy_asyncio_thread_task(PyObject *loop) {
    PyObject *ret = Py_None;
    PyInterpreterState *interp = _PyInterpreterState_GET();
    _PyEval_StopTheWorld(interp);
    _Py_FOR_EACH_TSTATE_BEGIN(interp, p) {
        _PyThreadStateImpl *ts = (_PyThreadStateImpl *)p;
        if (ts->asyncio_running_loop == loop) {
            if (ts->asyncio_running_task != NULL) ret = ts->asyncio_running_task;
            break;
        }
    }
    _Py_FOR_EACH_TSTATE_END(interp);
    Py_INCREF(ret);
    _PyEval_StartTheWorld(interp);
    return ret;
}
static int64_t jacpy_asyncio_add_list(struct llist_node *head, PyObject *tasks, int64_t node_offset) {
    struct llist_node *node;
    llist_for_each_safe(node, head) {
        PyObject *task = (PyObject *)((char *)node - node_offset);
        /* The lists hold borrowed references: skip a task being deallocated. */
        if (_Py_TryIncref(task) && _PyList_AppendTakeRef((PyListObject *)tasks, task) < 0) return -1;
    }
    return 0;
}
/* all_tasks(): append the registered tasks to the list `tasks`, those of the
 * current thread or, with `all_threads`, of the interpreter and every thread
 * with the world stopped. */
int64_t jacpy_asyncio_add_tasks(PyObject *tasks, int64_t node_offset, int64_t all_threads) {
    if (!all_threads) {
        return jacpy_asyncio_add_list(&((_PyThreadStateImpl *)_PyThreadState_GET())->asyncio_tasks_head, tasks, node_offset);
    }
    PyInterpreterState *interp = _PyInterpreterState_GET();
    _PyEval_StopTheWorld(interp);
    int64_t ret = jacpy_asyncio_add_list(&interp->asyncio_tasks_head, tasks, node_offset);
    if (ret == 0) {
        _Py_FOR_EACH_TSTATE_BEGIN(interp, p) {
            if (jacpy_asyncio_add_list(&((_PyThreadStateImpl *)p)->asyncio_tasks_head, tasks, node_offset) < 0) {
                ret = -1;
                break;
            }
        }
        _Py_FOR_EACH_TSTATE_END(interp);
    }
    _PyEval_StartTheWorld(interp);
    return ret;
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
void *jacpy_fdopendir(int32_t fd) { return fdopendir(fd); }
void jacpy_rewinddir(void *directory) { rewinddir((DIR *)directory); }
/* The next entry's name (NULL at the end) with its d_type, DT_UNKNOWN where
 * the C library has none, and its inode number. */
const char *jacpy_readdir_entry(void *directory, int64_t *type, uint64_t *inode) {
    struct dirent *entry = readdir((DIR *)directory);
    if (entry == NULL) return NULL;
#ifdef HAVE_DIRENT_D_TYPE
    *type = entry->d_type;
#else
    *type = DT_UNKNOWN;
#endif
    *inode = (uint64_t)entry->d_ino;
    return entry->d_name;
}

/* The stat family binds $INODE64 symbol variants on macOS x86_64 (and is
 * libc_nonshared inline wrappers on older glibc); each fills the target's
 * struct stat, which stat_records.jac lays out per target. */
#include <sys/stat.h>
#include "internal/pycore_fileutils.h"
int32_t jacpy_stat(const char *path, struct _Py_stat_struct *status) { return stat(path, status); }
int32_t jacpy_lstat(const char *path, struct _Py_stat_struct *status) { return lstat(path, status); }
int32_t jacpy_fstat(int32_t fd, struct _Py_stat_struct *status) { return fstat(fd, status); }
int32_t jacpy_fstatat(int32_t dir_fd, const char *path, struct _Py_stat_struct *status, int32_t flags) {
    return fstatat(dir_fd, path, status, flags);
}

/* macOS reads os.statvfs through struct statfs, whose statfs and fstatfs
 * bind $INODE64 variants on x86_64. */
#ifdef __APPLE__
#include <sys/mount.h>
int32_t jacpy_statfs(const char *path, void *buffer) { return statfs(path, (struct statfs *)buffer); }
int32_t jacpy_fstatfs(int32_t fd, void *buffer) { return fstatfs(fd, (struct statfs *)buffer); }
#endif

/* The fork hooks: the at-fork callback lists are interpreter-state fields,
 * HEAD_LOCK is a _PyRuntime field, and a forked child resets thread-state
 * fields (native id, remote-debugger request, asyncio task list), all of
 * whose offsets differ between builds. `which` is 0 for before_forkers, 1
 * for after_forkers_parent and 2 for after_forkers_child. */
#include "internal/pycore_llist.h"
#include "internal/pycore_tstate.h"
PyObject **jacpy_fork_callbacks(PyInterpreterState *interp, int64_t which) {
    return which == 0 ? &interp->before_forkers
        : which == 1 ? &interp->after_forkers_parent : &interp->after_forkers_child;
}
void jacpy_runtime_head_lock(void) { HEAD_LOCK(&_PyRuntime); }
void jacpy_runtime_head_unlock(void) { HEAD_UNLOCK(&_PyRuntime); }
void jacpy_thread_state_native_id(PyThreadState *tstate) {
#ifdef PY_HAVE_THREAD_NATIVE_ID
    tstate->native_thread_id = PyThread_get_thread_native_id();
#else
    (void)tstate;
#endif
}
void jacpy_thread_state_fork_reset(PyThreadState *tstate) {
    tstate->remote_debugger_support.debugger_pending_call = 0;
    memset(tstate->remote_debugger_support.debugger_script_path, 0, _Py_MAX_SCRIPT_PATH_SIZE);
    _PyThreadStateImpl *impl = (_PyThreadStateImpl *)tstate;
    llist_init(&impl->asyncio_tasks_head);
    impl->asyncio_running_loop = NULL;
    impl->asyncio_running_task = NULL;
}

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

/* PyBytes_FromFormatV, as Objects/bytesobject.c defines it. The rest of
 * bytes is object_model/bytes.jac; a Jac definition cannot receive a
 * va_list, so this one function stays C and writes through the Jac
 * _PyBytesWriter API. */
#include "internal/pycore_bytesobject.h"

PyObject *
PyBytes_FromFormatV(const char *format, va_list vargs)
{
    char *s;
    const char *f;
    const char *p;
    Py_ssize_t prec;
    int longflag;
    int size_tflag;
    /* Longest 64-bit formatted numbers:
       - "18446744073709551615\0" (21 bytes)
       - "-9223372036854775808\0" (21 bytes)
       Decimal takes the most space (it isn't enough for octal.)

       Longest 64-bit pointer representation:
       "0xffffffffffffffff\0" (19 bytes). */
    char buffer[21];
    _PyBytesWriter writer;

    _PyBytesWriter_Init(&writer);

    s = _PyBytesWriter_Alloc(&writer, strlen(format));
    if (s == NULL)
        return NULL;
    writer.overallocate = 1;

#define WRITE_BYTES(str) \
    do { \
        s = _PyBytesWriter_WriteBytes(&writer, s, (str), strlen(str)); \
        if (s == NULL) \
            goto error; \
    } while (0)

    for (f = format; *f; f++) {
        if (*f != '%') {
            *s++ = *f;
            continue;
        }

        p = f++;

        /* ignore the width (ex: 10 in "%10s") */
        while (Py_ISDIGIT(*f))
            f++;

        /* parse the precision (ex: 10 in "%.10s") */
        prec = 0;
        if (*f == '.') {
            f++;
            for (; Py_ISDIGIT(*f); f++) {
                prec = (prec * 10) + (*f - '0');
            }
        }

        while (*f && *f != '%' && !Py_ISALPHA(*f))
            f++;

        /* handle the long flag ('l'), but only for %ld and %lu.
           others can be added when necessary. */
        longflag = 0;
        if (*f == 'l' && (f[1] == 'd' || f[1] == 'u')) {
            longflag = 1;
            ++f;
        }

        /* handle the size_t flag ('z'). */
        size_tflag = 0;
        if (*f == 'z' && (f[1] == 'd' || f[1] == 'u')) {
            size_tflag = 1;
            ++f;
        }

        /* subtract bytes preallocated for the format string
           (ex: 2 for "%s") */
        writer.min_size -= (f - p + 1);

        switch (*f) {
        case 'c':
        {
            int c = va_arg(vargs, int);
            if (c < 0 || c > 255) {
                PyErr_SetString(PyExc_OverflowError,
                                "PyBytes_FromFormatV(): %c format "
                                "expects an integer in range [0; 255]");
                goto error;
            }
            writer.min_size++;
            *s++ = (unsigned char)c;
            break;
        }

        case 'd':
            if (longflag) {
                sprintf(buffer, "%ld", va_arg(vargs, long));
            }
            else if (size_tflag) {
                sprintf(buffer, "%zd", va_arg(vargs, Py_ssize_t));
            }
            else {
                sprintf(buffer, "%d", va_arg(vargs, int));
            }
            assert(strlen(buffer) < sizeof(buffer));
            WRITE_BYTES(buffer);
            break;

        case 'u':
            if (longflag) {
                sprintf(buffer, "%lu", va_arg(vargs, unsigned long));
            }
            else if (size_tflag) {
                sprintf(buffer, "%zu", va_arg(vargs, size_t));
            }
            else {
                sprintf(buffer, "%u", va_arg(vargs, unsigned int));
            }
            assert(strlen(buffer) < sizeof(buffer));
            WRITE_BYTES(buffer);
            break;

        case 'i':
            sprintf(buffer, "%i", va_arg(vargs, int));
            assert(strlen(buffer) < sizeof(buffer));
            WRITE_BYTES(buffer);
            break;

        case 'x':
            sprintf(buffer, "%x", va_arg(vargs, int));
            assert(strlen(buffer) < sizeof(buffer));
            WRITE_BYTES(buffer);
            break;

        case 's':
        {
            Py_ssize_t i;

            p = va_arg(vargs, const char*);
            if (prec <= 0) {
                i = strlen(p);
            }
            else {
                i = 0;
                while (i < prec && p[i]) {
                    i++;
                }
            }
            s = _PyBytesWriter_WriteBytes(&writer, s, p, i);
            if (s == NULL)
                goto error;
            break;
        }

        case 'p':
            sprintf(buffer, "%p", va_arg(vargs, void*));
            assert(strlen(buffer) < sizeof(buffer));
            /* %p is ill-defined:  ensure leading 0x. */
            if (buffer[1] == 'X')
                buffer[1] = 'x';
            else if (buffer[1] != 'x') {
                memmove(buffer+2, buffer, strlen(buffer)+1);
                buffer[0] = '0';
                buffer[1] = 'x';
            }
            WRITE_BYTES(buffer);
            break;

        case '%':
            writer.min_size++;
            *s++ = '%';
            break;

        default:
            if (*f == 0) {
                /* fix min_size if we reached the end of the format string */
                writer.min_size++;
            }

            /* invalid format string: copy unformatted string and exit */
            WRITE_BYTES(p);
            return _PyBytesWriter_Finish(&writer, s);
        }
    }

#undef WRITE_BYTES

    return _PyBytesWriter_Finish(&writer, s);

 error:
    _PyBytesWriter_Dealloc(&writer);
    return NULL;
}

/* PyUnicode_FromFormatV, PyUnicode_FromFormat and PyUnicodeWriter_Format,
 * as Objects/unicodeobject.c defines them. The rest of str is
 * object_model/unicode.jac; a Jac definition cannot receive a va_list, so
 * the printf-style formatter stays C and writes through the Jac
 * _PyUnicodeWriter / PyUnicodeWriter API, which keeps the C layout of
 * _PyUnicodeWriter, so the header's _PyUnicodeWriter_Prepare macro works
 * unchanged. Where unicodeobject.c calls one of its statics, this file calls
 * the exported equivalent:
 *   _PyUnicodeWriter_WriteCharInline -> _PyUnicodeWriter_WriteChar (its
 *       exported body, the same code);
 *   unicode_decode_utf8_writer(..., _Py_ERROR_REPLACE, "replace", ...) ->
 *       PyUnicodeWriter_DecodeUTF8Stateful(..., "replace", ...) (resolves the
 *       same handler; on failure it also rewinds pos, which the callers here
 *       discard or rewind anyway);
 *   ucs1lib_find_max_char(format) < 128 -> a scan for the first non-ASCII
 *       byte, which the error message needs in any case.
 * See ../LICENSE.cpython. */
#include <Python.h>
#include <stdint.h>
#include <string.h>
#include <wchar.h>
#include "internal/pycore_format.h"        /* F_LJUST, F_ZERO, F_ALT */
#include "internal/pycore_typeobject.h"    /* _PyType_GetFullyQualifiedName */
#include "internal/pycore_unicodeobject.h" /* _PyUnicode_FastCopyCharacters */

#define MAX_UNICODE 0x10ffff

/* maximum number of characters required for output of %jo or %jd or %p.
   We need at most ceil(log8(256)*sizeof(intmax_t)) digits,
   plus 1 for the sign, plus 2 for the 0x prefix (for %p),
   plus 1 for the terminal NUL. */
#define MAX_INTMAX_CHARS (5 + (sizeof(intmax_t)*8-1) / 3)

static int
unicode_fromformat_write_str(_PyUnicodeWriter *writer, PyObject *str,
                             Py_ssize_t width, Py_ssize_t precision, int flags)
{
    Py_ssize_t length, fill, arglen;
    Py_UCS4 maxchar;

    length = PyUnicode_GET_LENGTH(str);
    if ((precision == -1 || precision >= length)
        && width <= length)
        return _PyUnicodeWriter_WriteStr(writer, str);

    if (precision != -1)
        length = Py_MIN(precision, length);

    arglen = Py_MAX(length, width);
    if (PyUnicode_MAX_CHAR_VALUE(str) > writer->maxchar)
        maxchar = _PyUnicode_FindMaxChar(str, 0, length);
    else
        maxchar = writer->maxchar;

    if (_PyUnicodeWriter_Prepare(writer, arglen, maxchar) == -1)
        return -1;

    fill = Py_MAX(width - length, 0);
    if (fill && !(flags & F_LJUST)) {
        if (PyUnicode_Fill(writer->buffer, writer->pos, fill, ' ') == -1)
            return -1;
        writer->pos += fill;
    }

    _PyUnicode_FastCopyCharacters(writer->buffer, writer->pos,
                                  str, 0, length);
    writer->pos += length;

    if (fill && (flags & F_LJUST)) {
        if (PyUnicode_Fill(writer->buffer, writer->pos, fill, ' ') == -1)
            return -1;
        writer->pos += fill;
    }

    return 0;
}

static int
unicode_fromformat_write_utf8(_PyUnicodeWriter *writer, const char *str,
                              Py_ssize_t width, Py_ssize_t precision, int flags)
{
    /* UTF-8 */
    Py_ssize_t *pconsumed = NULL;
    Py_ssize_t length;
    if (precision == -1) {
        length = strlen(str);
    }
    else {
        length = 0;
        while (length < precision && str[length]) {
            length++;
        }
        if (length == precision) {
            /* The input string is not NUL-terminated.  If it ends with an
             * incomplete UTF-8 sequence, truncate the string just before it.
             * Incomplete sequences in the middle and sequences which cannot
             * be valid prefixes are still treated as errors and replaced
             * with \xfffd. */
            pconsumed = &length;
        }
    }

    if (width < 0) {
        return PyUnicodeWriter_DecodeUTF8Stateful((PyUnicodeWriter *)writer,
                                                  str, length, "replace",
                                                  pconsumed);
    }

    PyObject *unicode = PyUnicode_DecodeUTF8Stateful(str, length,
                                                     "replace", pconsumed);
    if (unicode == NULL)
        return -1;

    int res = unicode_fromformat_write_str(writer, unicode,
                                           width, -1, flags);
    Py_DECREF(unicode);
    return res;
}

static int
unicode_fromformat_write_wcstr(_PyUnicodeWriter *writer, const wchar_t *str,
                              Py_ssize_t width, Py_ssize_t precision, int flags)
{
    Py_ssize_t length;
    if (precision == -1) {
        length = wcslen(str);
    }
    else {
        length = 0;
        while (length < precision && str[length]) {
            length++;
        }
    }

    if (width < 0) {
        return PyUnicodeWriter_WriteWideChar((PyUnicodeWriter*)writer,
                                             str, length);
    }

    PyObject *unicode = PyUnicode_FromWideChar(str, length);
    if (unicode == NULL)
        return -1;

    int res = unicode_fromformat_write_str(writer, unicode, width, -1, flags);
    Py_DECREF(unicode);
    return res;
}

#define F_LONG 1
#define F_LONGLONG 2
#define F_SIZE 3
#define F_PTRDIFF 4
#define F_INTMAX 5

static const char*
unicode_fromformat_arg(_PyUnicodeWriter *writer,
                       const char *f, va_list *vargs)
{
    const char *p;
    Py_ssize_t len;
    int flags = 0;
    Py_ssize_t width;
    Py_ssize_t precision;

    p = f;
    f++;
    if (*f == '%') {
        if (_PyUnicodeWriter_WriteChar(writer, '%') < 0)
            return NULL;
        f++;
        return f;
    }

    /* Parse flags. Example: "%-i" => flags=F_LJUST. */
    /* Flags '+', ' ' and '#' are not particularly useful.
     * They are not worth the implementation and maintenance costs.
     * In addition, '#' should add "0" for "o" conversions for compatibility
     * with printf, but it would confuse Python users. */
    while (1) {
        switch (*f++) {
        case '-': flags |= F_LJUST; continue;
        case '0': flags |= F_ZERO; continue;
        case '#': flags |= F_ALT; continue;
        }
        f--;
        break;
    }

    /* parse the width.precision part, e.g. "%2.5s" => width=2, precision=5 */
    width = -1;
    if (*f == '*') {
        width = va_arg(*vargs, int);
        if (width < 0) {
            flags |= F_LJUST;
            width = -width;
        }
        f++;
    }
    else if (Py_ISDIGIT((unsigned)*f)) {
        width = *f - '0';
        f++;
        while (Py_ISDIGIT((unsigned)*f)) {
            if (width > (PY_SSIZE_T_MAX - ((int)*f - '0')) / 10) {
                PyErr_SetString(PyExc_ValueError,
                                "width too big");
                return NULL;
            }
            width = (width * 10) + (*f - '0');
            f++;
        }
    }
    precision = -1;
    if (*f == '.') {
        f++;
        if (*f == '*') {
            precision = va_arg(*vargs, int);
            if (precision < 0) {
                precision = -2;
            }
            f++;
        }
        else if (Py_ISDIGIT((unsigned)*f)) {
            precision = (*f - '0');
            f++;
            while (Py_ISDIGIT((unsigned)*f)) {
                if (precision > (PY_SSIZE_T_MAX - ((int)*f - '0')) / 10) {
                    PyErr_SetString(PyExc_ValueError,
                                    "precision too big");
                    return NULL;
                }
                precision = (precision * 10) + (*f - '0');
                f++;
            }
        }
    }

    int sizemod = 0;
    if (*f == 'l') {
        if (f[1] == 'l') {
            sizemod = F_LONGLONG;
            f += 2;
        }
        else {
            sizemod = F_LONG;
            ++f;
        }
    }
    else if (*f == 'z') {
        sizemod = F_SIZE;
        ++f;
    }
    else if (*f == 't') {
        sizemod = F_PTRDIFF;
        ++f;
    }
    else if (*f == 'j') {
        sizemod = F_INTMAX;
        ++f;
    }
    if (f[0] != '\0' && f[1] == '\0')
        writer->overallocate = 0;

    switch (*f) {
    case 'd': case 'i': case 'o': case 'u': case 'x': case 'X':
        break;
    case 'c': case 'p':
        if (sizemod || width >= 0 || precision >= 0) goto invalid_format;
        break;
    case 's':
    case 'V':
        if (sizemod && sizemod != F_LONG) goto invalid_format;
        break;
    default:
        if (sizemod) goto invalid_format;
        break;
    }

    switch (*f) {
    case 'c':
    {
        int ordinal = va_arg(*vargs, int);
        if (ordinal < 0 || ordinal > MAX_UNICODE) {
            PyErr_SetString(PyExc_OverflowError,
                            "character argument not in range(0x110000)");
            return NULL;
        }
        if (_PyUnicodeWriter_WriteChar(writer, ordinal) < 0)
            return NULL;
        break;
    }

    case 'd': case 'i':
    case 'o': case 'u': case 'x': case 'X':
    {
        char buffer[MAX_INTMAX_CHARS];

        // Fill buffer using sprinf, with one of many possible format
        // strings, like "%llX" for `long long` in hexadecimal.
        // The type/size is in `sizemod`; the format is in `*f`.

        // Use macros with nested switches to keep the sprintf format strings
        // as compile-time literals, avoiding warnings and maybe allowing
        // optimizations.

        // `SPRINT` macro does one sprintf
        // Example usage: SPRINT("l", "X", unsigned long) expands to
        // sprintf(buffer, "%" "l" "X", va_arg(*vargs, unsigned long))
        #define SPRINT(SIZE_SPEC, FMT_CHAR, TYPE) \
            sprintf(buffer, "%" SIZE_SPEC FMT_CHAR, va_arg(*vargs, TYPE))

        // One inner switch to handle all format variants
        #define DO_SPRINTS(SIZE_SPEC, SIGNED_TYPE, UNSIGNED_TYPE)             \
            switch (*f) {                                                     \
                case 'o': len = SPRINT(SIZE_SPEC, "o", UNSIGNED_TYPE); break; \
                case 'u': len = SPRINT(SIZE_SPEC, "u", UNSIGNED_TYPE); break; \
                case 'x': len = SPRINT(SIZE_SPEC, "x", UNSIGNED_TYPE); break; \
                case 'X': len = SPRINT(SIZE_SPEC, "X", UNSIGNED_TYPE); break; \
                default:  len = SPRINT(SIZE_SPEC, "d", SIGNED_TYPE); break;   \
            }

        // Outer switch to handle all the sizes/types
        switch (sizemod) {
            case F_LONG:     DO_SPRINTS("l", long, unsigned long); break;
            case F_LONGLONG: DO_SPRINTS("ll", long long, unsigned long long); break;
            case F_SIZE:     DO_SPRINTS("z", Py_ssize_t, size_t); break;
            case F_PTRDIFF:  DO_SPRINTS("t", ptrdiff_t, ptrdiff_t); break;
            case F_INTMAX:   DO_SPRINTS("j", intmax_t, uintmax_t); break;
            default:         DO_SPRINTS("", int, unsigned int); break;
        }
        #undef SPRINT
        #undef DO_SPRINTS

        assert(len >= 0);

        int sign = (buffer[0] == '-');
        len -= sign;

        precision = Py_MAX(precision, len);
        width = Py_MAX(width, precision + sign);
        if ((flags & F_ZERO) && !(flags & F_LJUST)) {
            precision = width - sign;
        }

        Py_ssize_t spacepad = Py_MAX(width - precision - sign, 0);
        Py_ssize_t zeropad = Py_MAX(precision - len, 0);

        if (_PyUnicodeWriter_Prepare(writer, width, 127) == -1)
            return NULL;

        if (spacepad && !(flags & F_LJUST)) {
            if (PyUnicode_Fill(writer->buffer, writer->pos, spacepad, ' ') == -1)
                return NULL;
            writer->pos += spacepad;
        }

        if (sign) {
            if (_PyUnicodeWriter_WriteChar(writer, '-') == -1)
                return NULL;
        }

        if (zeropad) {
            if (PyUnicode_Fill(writer->buffer, writer->pos, zeropad, '0') == -1)
                return NULL;
            writer->pos += zeropad;
        }

        if (_PyUnicodeWriter_WriteASCIIString(writer, &buffer[sign], len) < 0)
            return NULL;

        if (spacepad && (flags & F_LJUST)) {
            if (PyUnicode_Fill(writer->buffer, writer->pos, spacepad, ' ') == -1)
                return NULL;
            writer->pos += spacepad;
        }
        break;
    }

    case 'p':
    {
        char number[MAX_INTMAX_CHARS];

        len = sprintf(number, "%p", va_arg(*vargs, void*));
        assert(len >= 0);

        /* %p is ill-defined:  ensure leading 0x. */
        if (number[1] == 'X')
            number[1] = 'x';
        else if (number[1] != 'x') {
            memmove(number + 2, number,
                    strlen(number) + 1);
            number[0] = '0';
            number[1] = 'x';
            len += 2;
        }

        if (_PyUnicodeWriter_WriteASCIIString(writer, number, len) < 0)
            return NULL;
        break;
    }

    case 's':
    {
        if (sizemod) {
            const wchar_t *s = va_arg(*vargs, const wchar_t*);
            if (unicode_fromformat_write_wcstr(writer, s, width, precision, flags) < 0)
                return NULL;
        }
        else {
            /* UTF-8 */
            const char *s = va_arg(*vargs, const char*);
            if (unicode_fromformat_write_utf8(writer, s, width, precision, flags) < 0)
                return NULL;
        }
        break;
    }

    case 'U':
    {
        PyObject *obj = va_arg(*vargs, PyObject *);
        assert(obj && PyUnicode_Check(obj));

        if (unicode_fromformat_write_str(writer, obj, width, precision, flags) == -1)
            return NULL;
        break;
    }

    case 'V':
    {
        PyObject *obj = va_arg(*vargs, PyObject *);
        const char *str;
        const wchar_t *wstr;
        if (sizemod) {
            wstr = va_arg(*vargs, const wchar_t*);
        }
        else {
            str = va_arg(*vargs, const char *);
        }
        if (obj) {
            assert(PyUnicode_Check(obj));
            if (unicode_fromformat_write_str(writer, obj, width, precision, flags) == -1)
                return NULL;
        }
        else if (sizemod) {
            assert(wstr != NULL);
            if (unicode_fromformat_write_wcstr(writer, wstr, width, precision, flags) < 0)
                return NULL;
        }
        else {
            assert(str != NULL);
            if (unicode_fromformat_write_utf8(writer, str, width, precision, flags) < 0)
                return NULL;
        }
        break;
    }

    case 'S':
    {
        PyObject *obj = va_arg(*vargs, PyObject *);
        PyObject *str;
        assert(obj);
        str = PyObject_Str(obj);
        if (!str)
            return NULL;
        if (unicode_fromformat_write_str(writer, str, width, precision, flags) == -1) {
            Py_DECREF(str);
            return NULL;
        }
        Py_DECREF(str);
        break;
    }

    case 'R':
    {
        PyObject *obj = va_arg(*vargs, PyObject *);
        PyObject *repr;
        assert(obj);
        repr = PyObject_Repr(obj);
        if (!repr)
            return NULL;
        if (unicode_fromformat_write_str(writer, repr, width, precision, flags) == -1) {
            Py_DECREF(repr);
            return NULL;
        }
        Py_DECREF(repr);
        break;
    }

    case 'A':
    {
        PyObject *obj = va_arg(*vargs, PyObject *);
        PyObject *ascii;
        assert(obj);
        ascii = PyObject_ASCII(obj);
        if (!ascii)
            return NULL;
        if (unicode_fromformat_write_str(writer, ascii, width, precision, flags) == -1) {
            Py_DECREF(ascii);
            return NULL;
        }
        Py_DECREF(ascii);
        break;
    }

    case 'T':
    {
        PyObject *obj = va_arg(*vargs, PyObject *);
        PyTypeObject *type = (PyTypeObject *)Py_NewRef(Py_TYPE(obj));

        PyObject *type_name;
        if (flags & F_ALT) {
            type_name = _PyType_GetFullyQualifiedName(type, ':');
        }
        else {
            type_name = PyType_GetFullyQualifiedName(type);
        }
        Py_DECREF(type);
        if (!type_name) {
            return NULL;
        }

        if (unicode_fromformat_write_str(writer, type_name,
                                         width, precision, flags) == -1) {
            Py_DECREF(type_name);
            return NULL;
        }
        Py_DECREF(type_name);
        break;
    }

    case 'N':
    {
        PyObject *type_raw = va_arg(*vargs, PyObject *);
        assert(type_raw != NULL);

        if (!PyType_Check(type_raw)) {
            PyErr_SetString(PyExc_TypeError, "%N argument must be a type");
            return NULL;
        }
        PyTypeObject *type = (PyTypeObject*)type_raw;

        PyObject *type_name;
        if (flags & F_ALT) {
            type_name = _PyType_GetFullyQualifiedName(type, ':');
        }
        else {
            type_name = PyType_GetFullyQualifiedName(type);
        }
        if (!type_name) {
            return NULL;
        }
        if (unicode_fromformat_write_str(writer, type_name,
                                         width, precision, flags) == -1) {
            Py_DECREF(type_name);
            return NULL;
        }
        Py_DECREF(type_name);
        break;
    }

    default:
    invalid_format:
        PyErr_Format(PyExc_SystemError, "invalid format string: %s", p);
        return NULL;
    }

    f++;
    return f;
}

static int
unicode_from_format(_PyUnicodeWriter *writer, const char *format, va_list vargs)
{
    Py_ssize_t len = strlen(format);
    writer->min_length += len + 100;
    writer->overallocate = 1;

    // Copy varags to be able to pass a reference to a subfunction.
    va_list vargs2;
    va_copy(vargs2, vargs);

    // _PyUnicodeWriter_WriteASCIIString() below requires the format string
    // to be encoded to ASCII.
    Py_ssize_t i;
    for (i=0; i < len && (unsigned char)format[i] <= 127; i++);
    if (i < len) {
        PyErr_Format(PyExc_ValueError,
            "PyUnicode_FromFormatV() expects an ASCII-encoded format "
            "string, got a non-ASCII byte: 0x%02x",
            (unsigned char)format[i]);
        goto fail;
    }

    for (const char *f = format; *f; ) {
        if (*f == '%') {
            f = unicode_fromformat_arg(writer, f, &vargs2);
            if (f == NULL)
                goto fail;
        }
        else {
            const char *p = strchr(f, '%');
            if (p != NULL) {
                len = p - f;
            }
            else {
                len = strlen(f);
                writer->overallocate = 0;
            }

            if (_PyUnicodeWriter_WriteASCIIString(writer, f, len) < 0) {
                goto fail;
            }
            f += len;
        }
    }
    va_end(vargs2);
    return 0;

  fail:
    va_end(vargs2);
    return -1;
}

PyObject *
PyUnicode_FromFormatV(const char *format, va_list vargs)
{
    _PyUnicodeWriter writer;
    _PyUnicodeWriter_Init(&writer);

    if (unicode_from_format(&writer, format, vargs) < 0) {
        _PyUnicodeWriter_Dealloc(&writer);
        return NULL;
    }
    return _PyUnicodeWriter_Finish(&writer);
}

PyObject *
PyUnicode_FromFormat(const char *format, ...)
{
    PyObject* ret;
    va_list vargs;

    va_start(vargs, format);
    ret = PyUnicode_FromFormatV(format, vargs);
    va_end(vargs);
    return ret;
}

int
PyUnicodeWriter_Format(PyUnicodeWriter *writer, const char *format, ...)
{
    _PyUnicodeWriter *_writer = (_PyUnicodeWriter*)writer;
    Py_ssize_t old_pos = _writer->pos;

    va_list vargs;
    va_start(vargs, format);
    int res = unicode_from_format(_writer, format, vargs);
    va_end(vargs);

    if (res < 0) {
        _writer->pos = old_pos;
    }
    return res;
}

/* str's static strings: the generated _PyUnicode_InitStaticStrings is a
 * static inline over _PyRuntime's _Py_ID/_Py_STR objects, so
 * object_model/unicode.jac reaches it through this wrapper. */
#include "internal/pycore_runtime.h"
#include "internal/pycore_global_strings.h"
#include "internal/pycore_unicodeobject_generated.h"
void jacpy_unicode_init_static_strings(PyInterpreterState *interp) { _PyUnicode_InitStaticStrings(interp); }
/* A str from a Jac str argument, which arrives as its UTF-8 address: the C
 * definitions take a char pointer, which only a literal makes in Jac. */
PyObject *jacpy_unicode_from_text(const char *text) { return PyUnicode_FromString(text); }
PyObject *jacpy_unicode_intern_text(const char *text) { return PyUnicode_InternFromString(text); }
int jacpy_unicode_equal_text(PyObject *op, const char *text) { return PyUnicode_EqualToUTF8(op, text); }
int jacpy_unicode_writer_write_text(PyUnicodeWriter *writer, const char *text, Py_ssize_t size) { return PyUnicodeWriter_WriteASCII(writer, text, size); }




/* _Py_Dealloc, as Objects/object.c defines it for the release build. The
 * rest of object.c is object_model/object.jac; this function stays C because
 * its trashcan test reads the machine stack pointer against the thread's C
 * stack limit (_Py_RecursionLimit_GetMargin), which Jac cannot express, and
 * it runs on every deallocation, so the thread state comes from the
 * thread-local slot rather than a call. When the stack is nearly exhausted a
 * GC object is parked on the thread's delete_later list instead of being
 * deallocated (_PyTrash_thread_deposit_object, in Jac), and the list is
 * drained (_PyTrash_thread_destroy_chain) once the stack is shallower. */
#include "internal/pycore_object.h"
#include "internal/pycore_pystate.h"

void
_Py_Dealloc(PyObject *op)
{
    PyTypeObject *type = Py_TYPE(op);
    unsigned long gc_flag = type->tp_flags & Py_TPFLAGS_HAVE_GC;
    destructor dealloc = type->tp_dealloc;
    PyThreadState *tstate = _PyThreadState_GET();
    intptr_t margin = _Py_RecursionLimit_GetMargin(tstate);
    if (margin < 2 && gc_flag) {
        _PyTrash_thread_deposit_object(tstate, (PyObject *)op);
        return;
    }
    _PyReftracerTrack(op, PyRefTracer_DESTROY);
    (*dealloc)(op);
    if (tstate->delete_later && margin >= 4 && gc_flag) {
        _PyTrash_thread_destroy_chain(tstate);
    }
}

/* The stdio stream stdin (0), stdout (1) or stderr (2), for the object
 * dumps of object_model/object.jac: the streams are macros or differently
 * named globals across C libraries. */
FILE *jacpy_stdio_stream(int32_t stream) { return stream == 2 ? stderr : stream == 1 ? stdout : stdin; }
/* The attribute C API for a Jac str name, which arrives as its UTF-8 address. */
PyObject *jacpy_object_getattr_text(PyObject *op, const char *name) { return PyObject_GetAttrString(op, name); }
int jacpy_object_setattr_text(PyObject *op, const char *name, PyObject *value) { return PyObject_SetAttrString(op, name, value); }
int jacpy_object_getoptionalattr_text(PyObject *op, const char *name, PyObject **result) { return PyObject_GetOptionalAttrString(op, name, result); }

/* The va_list calls of Objects/call.c, as call.c defines them. The rest of
 * call.c is object_model/call.jac; a Jac definition cannot receive a
 * va_list, so the format-string calls, which build their argument stack from
 * one with _Py_VaBuildStack, and the variadic functions that only forward
 * theirs stay C. They call through the static inline
 * _PyObject_VectorcallTstate, whose _PyObject_MakeTpCall and
 * _Py_CheckFunctionResult are Jac. */
#include "internal/pycore_call.h"
#include "internal/pycore_modsupport.h"
#include "internal/pycore_pyerrors.h"
#include "internal/pycore_pystate.h"
#include "internal/pycore_tuple.h"

/* The address of a record a Jac caller lends with `&mut`. An `own` record
 * local that is only lent to a call with an int result is stack-promoted, so
 * call.jac and abstract.jac take the addresses of their small argument arrays
 * and Py_buffer views this way, without a heap allocation. */
intptr_t
jacpy_stack_address(void *slots)
{
    return (intptr_t)slots;
}

static PyObject *
call_null_error(PyThreadState *tstate)
{
    if (!_PyErr_Occurred(tstate)) {
        _PyErr_SetString(tstate, PyExc_SystemError,
                         "null argument to internal routine");
    }
    return NULL;
}

/* --- Call with a format string ---------------------------------- */

static PyObject *
_PyObject_CallFunctionVa(PyThreadState *tstate, PyObject *callable,
                         const char *format, va_list va)
{
    PyObject* small_stack[_PY_FASTCALL_SMALL_STACK];
    const Py_ssize_t small_stack_len = Py_ARRAY_LENGTH(small_stack);
    PyObject **stack;
    Py_ssize_t nargs, i;
    PyObject *result;

    if (callable == NULL) {
        return call_null_error(tstate);
    }

    if (!format || !*format) {
        return _PyObject_CallNoArgsTstate(tstate, callable);
    }

    stack = _Py_VaBuildStack(small_stack, small_stack_len,
                             format, va, &nargs);
    if (stack == NULL) {
        return NULL;
    }
    EVAL_CALL_STAT_INC_IF_FUNCTION(EVAL_CALL_API, callable);
    if (nargs == 1 && PyTuple_Check(stack[0])) {
        /* Special cases for backward compatibility:
           - PyObject_CallFunction(func, "O", tuple) calls func(*tuple)
           - PyObject_CallFunction(func, "(OOO)", arg1, arg2, arg3) calls
             func(*(arg1, arg2, arg3)): func(arg1, arg2, arg3) */
        PyObject *args = stack[0];
        result = _PyObject_VectorcallTstate(tstate, callable,
                                            _PyTuple_ITEMS(args),
                                            PyTuple_GET_SIZE(args),
                                            NULL);
    }
    else {
        result = _PyObject_VectorcallTstate(tstate, callable,
                                            stack, nargs, NULL);
    }

    for (i = 0; i < nargs; ++i) {
        Py_DECREF(stack[i]);
    }
    if (stack != small_stack) {
        PyMem_Free(stack);
    }
    return result;
}


PyObject *
PyObject_CallFunction(PyObject *callable, const char *format, ...)
{
    va_list va;
    PyObject *result;
    PyThreadState *tstate = _PyThreadState_GET();

    va_start(va, format);
    result = _PyObject_CallFunctionVa(tstate, callable, format, va);
    va_end(va);

    return result;
}


/* PyEval_CallFunction is exact copy of PyObject_CallFunction.
   Function removed in Python 3.13 API but kept in the stable ABI. */
PyAPI_FUNC(PyObject*)
PyEval_CallFunction(PyObject *callable, const char *format, ...)
{
    va_list va;
    PyObject *result;
    PyThreadState *tstate = _PyThreadState_GET();

    va_start(va, format);
    result = _PyObject_CallFunctionVa(tstate, callable, format, va);
    va_end(va);

    return result;
}


/* _PyObject_CallFunction_SizeT is exact copy of PyObject_CallFunction.
 * This function must be kept because it is part of the stable ABI.
 */
PyAPI_FUNC(PyObject *)  /* abi_only */
_PyObject_CallFunction_SizeT(PyObject *callable, const char *format, ...)
{
    PyThreadState *tstate = _PyThreadState_GET();

    va_list va;
    va_start(va, format);
    PyObject *result = _PyObject_CallFunctionVa(tstate, callable, format, va);
    va_end(va);

    return result;
}


static PyObject*
callmethod(PyThreadState *tstate, PyObject* callable, const char *format, va_list va)
{
    assert(callable != NULL);
    if (!PyCallable_Check(callable)) {
        _PyErr_Format(tstate, PyExc_TypeError,
                      "attribute of type '%.200s' is not callable",
                      Py_TYPE(callable)->tp_name);
        return NULL;
    }

    return _PyObject_CallFunctionVa(tstate, callable, format, va);
}

PyObject *
PyObject_CallMethod(PyObject *obj, const char *name, const char *format, ...)
{
    PyThreadState *tstate = _PyThreadState_GET();

    if (obj == NULL || name == NULL) {
        return call_null_error(tstate);
    }

    PyObject *callable = PyObject_GetAttrString(obj, name);
    if (callable == NULL) {
        return NULL;
    }

    va_list va;
    va_start(va, format);
    PyObject *retval = callmethod(tstate, callable, format, va);
    va_end(va);

    Py_DECREF(callable);
    return retval;
}


/* PyEval_CallMethod is exact copy of PyObject_CallMethod.
   Function removed in Python 3.13 API but kept in the stable ABI. */
PyAPI_FUNC(PyObject*)
PyEval_CallMethod(PyObject *obj, const char *name, const char *format, ...)
{
    PyThreadState *tstate = _PyThreadState_GET();
    if (obj == NULL || name == NULL) {
        return call_null_error(tstate);
    }

    PyObject *callable = PyObject_GetAttrString(obj, name);
    if (callable == NULL) {
        return NULL;
    }

    va_list va;
    va_start(va, format);
    PyObject *retval = callmethod(tstate, callable, format, va);
    va_end(va);

    Py_DECREF(callable);
    return retval;
}


PyObject *
_PyObject_CallMethod(PyObject *obj, PyObject *name,
                     const char *format, ...)
{
    PyThreadState *tstate = _PyThreadState_GET();
    if (obj == NULL || name == NULL) {
        return call_null_error(tstate);
    }

    PyObject *callable = PyObject_GetAttr(obj, name);
    if (callable == NULL) {
        return NULL;
    }

    va_list va;
    va_start(va, format);
    PyObject *retval = callmethod(tstate, callable, format, va);
    va_end(va);

    Py_DECREF(callable);
    return retval;
}


PyObject *
_PyObject_CallMethodId(PyObject *obj, _Py_Identifier *name,
                       const char *format, ...)
{
    PyThreadState *tstate = _PyThreadState_GET();
    if (obj == NULL || name == NULL) {
        return call_null_error(tstate);
    }

    PyObject *callable = _PyObject_GetAttrId(obj, name);
    if (callable == NULL) {
        return NULL;
    }

    va_list va;
    va_start(va, format);
    PyObject *retval = callmethod(tstate, callable, format, va);
    va_end(va);

    Py_DECREF(callable);
    return retval;
}


PyObject * _PyObject_CallMethodFormat(PyThreadState *tstate, PyObject *callable,
                                      const char *format, ...)
{
    assert(callable != NULL);
    va_list va;
    va_start(va, format);
    PyObject *retval = callmethod(tstate, callable, format, va);
    va_end(va);
    return retval;
}


// _PyObject_CallMethod_SizeT is exact copy of PyObject_CallMethod.
// This function must be kept because it is part of the stable ABI.
PyAPI_FUNC(PyObject *)  /* abi_only */
_PyObject_CallMethod_SizeT(PyObject *obj, const char *name,
                           const char *format, ...)
{
    PyThreadState *tstate = _PyThreadState_GET();
    if (obj == NULL || name == NULL) {
        return call_null_error(tstate);
    }

    PyObject *callable = PyObject_GetAttrString(obj, name);
    if (callable == NULL) {
        return NULL;
    }

    va_list va;
    va_start(va, format);
    PyObject *retval = callmethod(tstate, callable, format, va);
    va_end(va);

    Py_DECREF(callable);
    return retval;
}
