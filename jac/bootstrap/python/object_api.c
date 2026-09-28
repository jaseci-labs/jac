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
PyObject *jacpy_slot_item(void *slot, PyObject *handle, int64_t index) {
    return ((ssizeargfunc)(uintptr_t)slot)(handle, (Py_ssize_t)index);
}
int64_t jacpy_less(PyObject *left, PyObject *right) {
    return PyObject_RichCompareBool(left, right, Py_LT);
}
int64_t jacpy_insert(PyObject *handle, int64_t index, PyObject *value) {
    if (PyList_CheckExact(handle))
        return PyList_Insert(handle, (Py_ssize_t)index, value);
    PyObject *result = PyObject_CallMethod(handle, "insert", "nO",
                                         (Py_ssize_t)index, value);
    if (!result) return -1;
    Py_DECREF(result);
    return 0;
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
/* -2 preserves NotImplemented so Jac can disable a cached fast comparison. */
int64_t jacpy_slot_less(void *slot, PyObject *left, PyObject *right) {
    PyObject *result = ((richcmpfunc)(uintptr_t)slot)(left, right, Py_LT);
    if (!result) return -1;
    int comparison = result == Py_NotImplemented ? -2 : PyObject_IsTrue(result);
    Py_DECREF(result);
    return comparison;
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
PyObject *jacpy_buffer_bytes(const Py_buffer *view) {
    if (PyBytes_CheckExact(view->obj) && view->buf == PyBytes_AS_STRING(view->obj)
        && view->len == PyBytes_GET_SIZE(view->obj)) return Py_NewRef(view->obj);
    return PyBytes_FromStringAndSize(view->buf, view->len);
}
Py_buffer *jacpy_buffer_acquire(PyObject *value, int64_t ascii) {
    Py_buffer *view = PyMem_Calloc(1, sizeof(*view));
    if (!view) { PyErr_NoMemory(); return NULL; }
    int ok = ascii ? jacpy_ascii_buffer(value, view)
                   : jacpy_binary_buffer(value, view);
    if (!ok) { PyMem_Free(view); return NULL; }
    return view;
}
Py_buffer *jacpy_buffer_acquire_writable(PyObject *value) {
    Py_buffer *view = PyMem_Calloc(1, sizeof(*view));
    if (!view) { PyErr_NoMemory(); return NULL; }
    if (!PyArg_Parse(value, "w*", view)) { PyMem_Free(view); return NULL; }
    return view;
}
PyObject *jacpy_buffer_owner(Py_buffer *value) {
    return value ? ((value)->obj) : 0;
}
int64_t jacpy_number_ssize(PyObject *value, const char *overflow) {
    extern PyObject *jacpy_exception_type(const char *);
    return PyNumber_AsSsize_t(value, jacpy_exception_type(overflow));
}
void jacpy_buffer_release(Py_buffer *value) {
    if (!value) return;
    Py_buffer *view = value;
    PyBuffer_Release(view);
    PyMem_Free(view);
}
void *jacpy_buffer_address(Py_buffer *value) {
    return (value)->buf;
}
int64_t jacpy_buffer_length(Py_buffer *value) {
    return (value)->len;
}
int64_t jacpy_buffer_dimensions(Py_buffer *value) {
    return (value)->ndim;
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
int64_t jacpy_is_none(PyObject *a) { return a == Py_None; }
int64_t jacpy_is_unicode(PyObject *a) { return PyUnicode_Check(a); }
PyObject *jacpy_unicode_split(PyObject *a, PyObject *sep) { return PyUnicode_Split(a, sep, -1); }
int64_t jacpy_dict_size(PyObject *a) { return a ? PyDict_Size(a) : 0; }
PyObject *jacpy_dict_entry(PyObject *a, int64_t position) {
    Py_ssize_t pos = position;
    PyObject *key, *value;
    if (!PyDict_Next(a, &pos, &key, &value)) return NULL;
    return Py_BuildValue("nOO", pos, key, value);
}
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
extern PyObject *jacpy_exception_type(const char *);
void jacpy_raise_value(const char *kind, PyObject *value) {
    PyObject *type = jacpy_exception_type(kind);
    if (type) PyErr_SetObject(type, value);
}
int64_t jacpy_is_bool(PyObject *value) { return PyBool_Check(value); }
int64_t jacpy_is_float(PyObject *value) { return PyFloat_Check(value); }
int64_t jacpy_is_dict(PyObject *value) { return PyDict_Check(value); }
int64_t jacpy_is_exact_dict(PyObject *value) { return PyDict_CheckExact(value); }
PyObject *jacpy_long_repr(PyObject *value) { return PyLong_Type.tp_repr(value); }
PyObject *jacpy_float_repr(PyObject *value) { return PyFloat_Type.tp_repr(value); }
PyObject *jacpy_type_name(PyObject *value) { return PyUnicode_FromString(Py_TYPE(value)->tp_name); }
PyObject *jacpy_qualified_type_name(PyObject *value) { return PyType_GetFullyQualifiedName(Py_TYPE(value)); }
int64_t jacpy_exception_note(PyObject *error, PyObject *note) {
    PyObject *result = PyObject_CallMethod(error, "add_note", "O", note);
    if (!result) return -1;
    Py_DECREF(result); return 0;
}
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
int64_t jacpy_memory_byte(void *address, int64_t offset) { return ((unsigned char *)address)[offset]; }
void jacpy_memory_set(void *address, int64_t offset, int64_t value) { ((unsigned char *)address)[offset] = (unsigned char)value; }
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

void jacpy_set_key_error(PyObject *key) {
    PyObject *args = PyTuple_Pack(1, key);
    if (args) { PyErr_SetObject(PyExc_KeyError, args); Py_DECREF(args); }
}

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
PyObject *jacpy_libm_parts(double value, int64_t integral) {
    if(integral) { double whole; double fraction=modf(value,&whole); return Py_BuildValue("dd",fraction,whole); }
    int exponent=0; double fraction=frexp(value,&exponent); return Py_BuildValue("di",fraction,exponent);
}
uint64_t jacpy_float_bits(double value) { uint64_t bits; memcpy(&bits,&value,sizeof(bits)); return bits; }
double jacpy_float_from_bits(uint64_t bits) { double value; memcpy(&value,&bits,sizeof(value)); return value; }
PyObject *jacpy_long_frexp(PyObject *value) {
    int64_t exponent; double fraction=_PyLong_Frexp((PyLongObject *)value,&exponent);
    return PyErr_Occurred() ? NULL : Py_BuildValue("dL",fraction,(long long)exponent);
}


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
PyObject *jacpy_ordered_dict_new(void) { return PyObject_CallNoArgs((PyObject *)&PyODict_Type); }

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

/* Exact built-in categories: subclasses use their object protocols instead. */
static PyTypeObject *const builtin_types[] = {
    NULL, &PyBool_Type, &PyLong_Type, &PyFloat_Type, &PyBytes_Type,
    &PyUnicode_Type, &PyTuple_Type, &PyList_Type, &PyDict_Type, &PySet_Type,
    &PyFrozenSet_Type, &PyByteArray_Type, &PyType_Type, &PyFunction_Type,
    &PyPickleBuffer_Type
};
int64_t jacpy_builtin_kind(PyObject *value) {
    PyObject *object = value;
    if (object == Py_None) return 0;
    for (size_t i = 1; i < sizeof(builtin_types) / sizeof(*builtin_types); ++i)
        if (Py_TYPE(object) == builtin_types[i]) return (int64_t)i;
    return 15;
}
PyObject *jacpy_builtin_type(int64_t kind) {
    if (kind == 0) return Py_NewRef((PyObject *)Py_TYPE(Py_None));
    if (kind < 0 || (uint64_t)kind >= sizeof(builtin_types) / sizeof(*builtin_types)) {
        PyErr_SetString(PyExc_SystemError, "invalid built-in type category"); return NULL;
    }
    return Py_NewRef((PyObject *)builtin_types[kind]);
}

int64_t jacpy_is_not_implemented(PyObject *value) { return value == Py_NotImplemented; }

int64_t jacpy_audit_pickle_find(PyObject *module, PyObject *name) { return PySys_Audit("pickle.find_class", "OO", module, name); }

PyObject *jacpy_mapping_optional_item(PyObject *mapping, PyObject *key) { PyObject *result = NULL; return PyMapping_GetOptionalItem(mapping, key, &result) < 0 ? NULL : result; }


PyObject *jacpy_not_implemented(void) { return Py_NewRef(Py_NotImplemented); }
PyObject *jacpy_ellipsis(void) { return Py_NewRef(Py_Ellipsis); }

void jacpy_exception_context(PyObject *error, PyObject *cause) { PyException_SetContext(error, Py_NewRef(cause)); }

PyObject *jacpy_unicode_intern(PyObject *value) { PyObject *result=Py_NewRef(value); PyUnicode_InternInPlace(&result); return result; }

int64_t jacpy_dict_memory(PyObject *value) {
    PyObject *size = PyObject_CallMethod(value, "__sizeof__", NULL);
    if (!size) return -1;
    Py_ssize_t result = PyLong_AsSsize_t(size);
    Py_DECREF(size);
    return result;
}

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
int64_t jacpy_warn(const char *category, const char *message, int64_t stacklevel) {
    extern PyObject *jacpy_exception_type(const char *);
    return PyErr_WarnEx(jacpy_exception_type(category), message, stacklevel);
}
PyObject *jacpy_builtins(void) { return Py_NewRef(PyEval_GetBuiltins()); }
#pragma GCC visibility pop

/* A NUL-terminated string that C owns (a libc record field, an environment
 * entry), decoded with the filesystem encoding; NULL becomes None. */
PyObject *jacpy_fs_text(const void *text) {
    return text ? PyUnicode_DecodeFSDefault(text) : Py_NewRef(Py_None);
}

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

/* Interpreter objects that C defines as data symbols (static types and
 * singletons) or as interpreter state, looked up by their C name. Borrowed;
 * NULL with no exception set for an unknown name. */
#include "internal/pycore_descrobject.h"
#include "internal/pycore_namespace.h"
#include "internal/pycore_unionobject.h"
#include "internal/pycore_typevarobject.h"
#include "internal/pycore_interp.h"
#include "internal/pycore_pystate.h"
PyObject *jacpy_runtime_object(const char *name) {
    static const struct { const char *name; PyObject *value; } objects[] = {
#define OBJECT_ENTRY(symbol) {#symbol, (PyObject *)&symbol}
        OBJECT_ENTRY(PyAsyncGen_Type), OBJECT_ENTRY(PyCFunction_Type), OBJECT_ENTRY(PyCapsule_Type),
        OBJECT_ENTRY(PyCell_Type), OBJECT_ENTRY(PyClassMethodDescr_Type), OBJECT_ENTRY(PyCode_Type),
        OBJECT_ENTRY(PyCoro_Type), OBJECT_ENTRY(PyEllipsis_Type), OBJECT_ENTRY(PyFrame_Type),
        OBJECT_ENTRY(PyFunction_Type), OBJECT_ENTRY(PyGen_Type), OBJECT_ENTRY(Py_GenericAliasType),
        OBJECT_ENTRY(PyGetSetDescr_Type), OBJECT_ENTRY(PyDictProxy_Type), OBJECT_ENTRY(PyMemberDescr_Type),
        OBJECT_ENTRY(PyMethodDescr_Type), OBJECT_ENTRY(PyMethod_Type), OBJECT_ENTRY(_PyMethodWrapper_Type),
        OBJECT_ENTRY(PyModule_Type), OBJECT_ENTRY(_PyNone_Type), OBJECT_ENTRY(_PyNotImplemented_Type),
        OBJECT_ENTRY(_PyNamespace_Type), OBJECT_ENTRY(PyTraceBack_Type), OBJECT_ENTRY(_PyUnion_Type),
        OBJECT_ENTRY(PyWrapperDescr_Type), OBJECT_ENTRY(_PyTypeAlias_Type), OBJECT_ENTRY(_Py_NoDefaultStruct),
        OBJECT_ENTRY(_PyWeakref_RefType), OBJECT_ENTRY(_PyWeakref_ProxyType), OBJECT_ENTRY(_PyWeakref_CallableProxyType),
#undef OBJECT_ENTRY
    };
    for (size_t i = 0; i < sizeof(objects) / sizeof(*objects); i++)
        if (strcmp(objects[i].name, name) == 0) return objects[i].value;
    PyInterpreterState *interp = _PyInterpreterState_GET();
#define CACHED(field) if (strcmp(name, #field) == 0) return (PyObject *)interp->cached_objects.field
    CACHED(typevar_type); CACHED(typevartuple_type); CACHED(paramspec_type);
    CACHED(paramspecargs_type); CACHED(paramspeckwargs_type); CACHED(generic_type);
#undef CACHED
    return NULL;
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

/* Pointer arithmetic for C-owned buffers. ptr[T] in Jac has no arithmetic,
 * so offsets into a block and distances between cursors come from here. */
void *jacpy_offset(void *address, int64_t offset) { return (char *)address + offset; }
int64_t jacpy_distance(const void *end, const void *start) { return (const char *)end - (const char *)start; }

/* syslog(3) is variadic; the module always logs one preformatted message. */
#include <syslog.h>
void jacpy_syslog(int32_t priority, const char *message) { syslog(priority, "%s", message); }

/* errno is a thread-local macro; read it through a function. */
int64_t jacpy_errno(void) { return errno; }

/* PyLong_AsNativeBytes into a uint64_t, the way modules convert rlim_t and
 * similar unsigned C types: -1 on error, 1 when the value needs more than
 * eight bytes, 0 when it fits. */
int64_t jacpy_long_u64_checked(PyObject *value, uint64_t *out) {
    Py_ssize_t bytes = PyLong_AsNativeBytes(value, out, sizeof(*out),
        Py_ASNATIVEBYTES_NATIVE_ENDIAN | Py_ASNATIVEBYTES_UNSIGNED_BUFFER);
    if (bytes < 0) return -1;
    return bytes > (Py_ssize_t)sizeof(*out);
}

/* The address an int denotes, as struct's 'P' format packs it. */
uint64_t jacpy_long_address(PyObject *value) { return (uint64_t)(uintptr_t)PyLong_AsVoidPtr(value); }
