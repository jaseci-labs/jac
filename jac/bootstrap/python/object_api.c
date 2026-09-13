/* CPython value/slot operations shared by native Jac standard-library modules.
 * The calling native function holds the GIL. Handles are borrowed on input;
 * object results are new references. Algorithms belong in runtime/python/. */
#include <Python.h>
#include <errno.h>
#include <stdint.h>

#define OBJECT(h) ((PyObject *)(uintptr_t)(h))
#define HANDLE(p) ((uint64_t)(uintptr_t)(p))

int64_t jacpy_object_size(uint64_t handle) {
    return PySequence_Size(OBJECT(handle));
}
int64_t jacpy_ssize(uint64_t handle) { return PyLong_AsSsize_t(OBJECT(handle)); }
uint64_t jacpy_sequence_slot(uint64_t handle) {
    PyTypeObject *type = Py_TYPE(OBJECT(handle));
    if (type->tp_as_sequence && type->tp_as_sequence->sq_item)
        return (uint64_t)(uintptr_t)type->tp_as_sequence->sq_item;
    PyErr_Format(PyExc_TypeError,
        type->tp_as_mapping && type->tp_as_mapping->mp_subscript
            ? "%.200s is not a sequence"
            : "'%.200s' object does not support indexing", type->tp_name);
    return 0;
}
uint64_t jacpy_slot_item(uint64_t slot, uint64_t handle, int64_t index) {
    return HANDLE(((ssizeargfunc)(uintptr_t)slot)(OBJECT(handle), (Py_ssize_t)index));
}
uint64_t jacpy_call_one(uint64_t callable, uint64_t argument) {
    return HANDLE(PyObject_CallOneArg(OBJECT(callable), OBJECT(argument)));
}
int64_t jacpy_less(uint64_t left, uint64_t right) {
    return PyObject_RichCompareBool(OBJECT(left), OBJECT(right), Py_LT);
}
int64_t jacpy_insert(uint64_t handle, int64_t index, uint64_t value) {
    if (PyList_CheckExact(OBJECT(handle)))
        return PyList_Insert(OBJECT(handle), (Py_ssize_t)index, OBJECT(value));
    PyObject *result = PyObject_CallMethod(OBJECT(handle), "insert", "nO",
                                         (Py_ssize_t)index, OBJECT(value));
    if (!result) return -1;
    Py_DECREF(result);
    return 0;
}
int64_t jacpy_recursion_enter(const char *context) {
    /* Unlike most CPython status APIs this may return positive on failure. */
    return Py_EnterRecursiveCall(context) ? -1 : 0;
}
void jacpy_recursion_leave(void) { Py_LeaveRecursiveCall(); }

uint64_t jacpy_retain(uint64_t handle) { return HANDLE(Py_NewRef(OBJECT(handle))); }
uint64_t jacpy_list_item(uint64_t handle, int64_t index) {
    return HANDLE(PyList_GetItemRef(OBJECT(handle), (Py_ssize_t)index));
}
int64_t jacpy_list_size(uint64_t handle) { return PyList_GET_SIZE(OBJECT(handle)); }
int64_t jacpy_list_append(uint64_t handle, uint64_t value) {
    return PyList_Append(OBJECT(handle), OBJECT(value));
}
int64_t jacpy_list_delete(uint64_t handle, int64_t start, int64_t end) {
    return PyList_SetSlice(OBJECT(handle), (Py_ssize_t)start, (Py_ssize_t)end, NULL);
}
/* Exchange transfers the slot's reference to the caller; it cannot invoke a
 * finalizer while a native caller is still adjusting its container. */
uint64_t jacpy_list_exchange(uint64_t handle, int64_t index, uint64_t value) {
    PyObject *old = PyList_GetItem(OBJECT(handle), (Py_ssize_t)index);
    if (!old) return 0;
    PyList_SET_ITEM(OBJECT(handle), index, Py_NewRef(OBJECT(value)));
    return HANDLE(old);
}
void jacpy_list_swap(uint64_t handle, int64_t left, int64_t right) {
    PyObject *a = PyList_GET_ITEM(OBJECT(handle), left);
    PyObject *b = PyList_GET_ITEM(OBJECT(handle), right);
    PyList_SET_ITEM(OBJECT(handle), left, b);
    PyList_SET_ITEM(OBJECT(handle), right, a);
}

uint64_t jacpy_comparison_slot(uint64_t handle) {
    return (uint64_t)(uintptr_t)Py_TYPE(OBJECT(handle))->tp_richcompare;
}
int64_t jacpy_same_type(uint64_t left, uint64_t right) {
    return Py_TYPE(OBJECT(left)) == Py_TYPE(OBJECT(right));
}
/* -2 preserves NotImplemented so Jac can disable a cached fast comparison. */
int64_t jacpy_slot_less(uint64_t slot, uint64_t left, uint64_t right) {
    PyObject *result = ((richcmpfunc)(uintptr_t)slot)(OBJECT(left), OBJECT(right), Py_LT);
    if (!result) return -1;
    int comparison = result == Py_NotImplemented ? -2 : PyObject_IsTrue(result);
    Py_DECREF(result);
    return comparison;
}

#include "internal/pycore_long.h"
#include "internal/pycore_object.h"
#include "internal/pycore_pylifecycle.h"
#include <unistd.h>

int64_t jacpy_is_long(uint64_t handle) { return PyLong_Check(OBJECT(handle)); }
uint64_t jacpy_long_absolute(uint64_t handle) {
    return HANDLE(PyLong_Type.tp_as_number->nb_absolute(OBJECT(handle)));
}
uint64_t jacpy_hash_unsigned(uint64_t handle) {
    Py_hash_t value = PyObject_Hash(OBJECT(handle));
    return value == -1 ? 0 : HANDLE(PyLong_FromSize_t((size_t)value));
}
int64_t jacpy_long_bits(uint64_t handle) { return _PyLong_NumBits(OBJECT(handle)); }
uint64_t jacpy_long_bytes(uint64_t handle, int64_t size) {
    PyObject *result = PyBytes_FromStringAndSize(NULL, size);
    if (!result) return 0;
    if (_PyLong_AsByteArray((PyLongObject *)OBJECT(handle),
            (unsigned char *)PyBytes_AS_STRING(result), size, 1, 0, 1) < 0) {
        Py_DECREF(result);
        return 0;
    }
    return HANDLE(result);
}
uint64_t jacpy_long_from_bytes(uint64_t handle) {
    return HANDLE(_PyLong_FromByteArray((const unsigned char *)PyBytes_AS_STRING(OBJECT(handle)),
                                      PyBytes_GET_SIZE(OBJECT(handle)), 1, 0));
}
uint64_t jacpy_unsigned_long(uint64_t handle) { return PyLong_AsUnsignedLong(OBJECT(handle)); }
uint64_t jacpy_entropy(int64_t size) {
    PyObject *result = PyBytes_FromStringAndSize(NULL, size);
    if (!result) return 0;
    if (_PyOS_URandomNonblock(PyBytes_AS_STRING(result), size) < 0) {
        Py_DECREF(result);
        return 0;
    }
    return HANDLE(result);
}
void jacpy_clear_error(void) { PyErr_Clear(); }
int64_t jacpy_wall_time(void) {
    PyTime_t value;
    return PyTime_Time(&value) < 0 ? -1 : value;
}
int64_t jacpy_monotonic_time(void) {
    PyTime_t value;
    return PyTime_Monotonic(&value) < 0 ? -1 : value;
}
int64_t jacpy_process_id(void) { return getpid(); }
int64_t jacpy_is_tuple(uint64_t handle) { return PyTuple_Check(OBJECT(handle)); }
int64_t jacpy_tuple_size(uint64_t handle) { return PyTuple_Size(OBJECT(handle)); }
uint64_t jacpy_tuple_new(int64_t size) { return HANDLE(PyTuple_New(size)); }
uint64_t jacpy_tuple_item(uint64_t handle, int64_t index) {
    return HANDLE(Py_XNewRef(PyTuple_GetItem(OBJECT(handle), index)));
}
int64_t jacpy_tuple_set_owned(uint64_t handle, int64_t index, uint64_t value) {
    if (!value) return -1;
    return PyTuple_SetItem(OBJECT(handle), index, OBJECT(value));
}

/* Argument converters keep an exported buffer alive through argument parsing
 * and the native call. This preserves resize guards and callback ordering. */
int jacpy_binary_buffer(PyObject *value, void *output) {
    Py_buffer *view = output;
    if (!value) { PyBuffer_Release(view); return 1; }
    if (PyObject_GetBuffer(value, view, PyBUF_SIMPLE) < 0) return 0;
    return Py_CLEANUP_SUPPORTED;
}
int jacpy_ascii_buffer(PyObject *value, void *output) {
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
uint64_t jacpy_buffer_bytes(const Py_buffer *view) {
    if (PyBytes_CheckExact(view->obj) && view->buf == PyBytes_AS_STRING(view->obj)
        && view->len == PyBytes_GET_SIZE(view->obj)) return HANDLE(Py_NewRef(view->obj));
    return HANDLE(PyBytes_FromStringAndSize(view->buf, view->len));
}
uint64_t jacpy_buffer_acquire(uint64_t value, int64_t ascii) {
    Py_buffer *view = PyMem_Calloc(1, sizeof(*view));
    if (!view) { PyErr_NoMemory(); return 0; }
    int ok = ascii ? jacpy_ascii_buffer(OBJECT(value), view)
                   : jacpy_binary_buffer(OBJECT(value), view);
    if (!ok) { PyMem_Free(view); return 0; }
    return HANDLE(view);
}
uint64_t jacpy_buffer_acquire_writable(uint64_t value) {
    Py_buffer *view = PyMem_Calloc(1, sizeof(*view));
    if (!view) { PyErr_NoMemory(); return 0; }
    if (!PyArg_Parse(OBJECT(value), "w*", view)) { PyMem_Free(view); return 0; }
    return HANDLE(view);
}
uint64_t jacpy_buffer_owner(uint64_t value) {
    return value ? HANDLE(((Py_buffer *)(uintptr_t)value)->obj) : 0;
}
int64_t jacpy_number_ssize(uint64_t value, const char *overflow) {
    extern PyObject *jacpy_exception_type(const char *);
    return PyNumber_AsSsize_t(OBJECT(value), jacpy_exception_type(overflow));
}
void jacpy_buffer_release(uint64_t value) {
    if (!value) return;
    Py_buffer *view = (Py_buffer *)(uintptr_t)value;
    PyBuffer_Release(view);
    PyMem_Free(view);
}
uint64_t jacpy_buffer_address(uint64_t value) {
    return HANDLE(((Py_buffer *)(uintptr_t)value)->buf);
}
int64_t jacpy_buffer_length(uint64_t value) {
    return ((Py_buffer *)(uintptr_t)value)->len;
}
int64_t jacpy_buffer_dimensions(uint64_t value) {
    return ((Py_buffer *)(uintptr_t)value)->ndim;
}
int64_t jacpy_buffer_supported(uint64_t value) { return PyObject_CheckBuffer(OBJECT(value)); }
int64_t jacpy_unicode_ascii(uint64_t value) { return PyUnicode_IS_ASCII(OBJECT(value)); }
uint64_t jacpy_unsigned_mask(uint64_t value) { return PyLong_AsUnsignedLongMask(OBJECT(value)); }
int64_t jacpy_unicode_read(uint64_t value, int64_t index) { return PyUnicode_ReadChar(OBJECT(value), index); }
void jacpy_set_exception(uint64_t type, const char *message, int64_t size) {
    PyObject *text = PyUnicode_DecodeUTF8(message, size, "surrogatepass");
    if (text) { PyErr_SetObject(OBJECT(type), text); Py_DECREF(text); }
}

/* Generic numeric and object protocol operations. */
#define BINARY_OBJECT(name, api) \
    uint64_t jacpy_##name(uint64_t a, uint64_t b) { return HANDLE(api(OBJECT(a), OBJECT(b))); }
#define UNARY_OBJECT(name, api) \
    uint64_t jacpy_##name(uint64_t a) { return HANDLE(api(OBJECT(a))); }
BINARY_OBJECT(add, PyNumber_Add)
BINARY_OBJECT(sub, PyNumber_Subtract)
BINARY_OBJECT(mul, PyNumber_Multiply)
BINARY_OBJECT(matmul, PyNumber_MatrixMultiply)
BINARY_OBJECT(floordiv, PyNumber_FloorDivide)
BINARY_OBJECT(truediv, PyNumber_TrueDivide)
BINARY_OBJECT(mod, PyNumber_Remainder)
BINARY_OBJECT(lshift, PyNumber_Lshift)
BINARY_OBJECT(rshift, PyNumber_Rshift)
BINARY_OBJECT(and_, PyNumber_And)
BINARY_OBJECT(xor, PyNumber_Xor)
BINARY_OBJECT(or_, PyNumber_Or)
BINARY_OBJECT(iadd, PyNumber_InPlaceAdd)
BINARY_OBJECT(isub, PyNumber_InPlaceSubtract)
BINARY_OBJECT(imul, PyNumber_InPlaceMultiply)
BINARY_OBJECT(imatmul, PyNumber_InPlaceMatrixMultiply)
BINARY_OBJECT(ifloordiv, PyNumber_InPlaceFloorDivide)
BINARY_OBJECT(itruediv, PyNumber_InPlaceTrueDivide)
BINARY_OBJECT(imod, PyNumber_InPlaceRemainder)
BINARY_OBJECT(ilshift, PyNumber_InPlaceLshift)
BINARY_OBJECT(irshift, PyNumber_InPlaceRshift)
BINARY_OBJECT(iand, PyNumber_InPlaceAnd)
BINARY_OBJECT(ixor, PyNumber_InPlaceXor)
BINARY_OBJECT(ior, PyNumber_InPlaceOr)
BINARY_OBJECT(concat, PySequence_Concat)
BINARY_OBJECT(iconcat, PySequence_InPlaceConcat)
BINARY_OBJECT(getitem, PyObject_GetItem)
UNARY_OBJECT(neg, PyNumber_Negative)
UNARY_OBJECT(pos, PyNumber_Positive)
UNARY_OBJECT(abs, PyNumber_Absolute)
UNARY_OBJECT(invert, PyNumber_Invert)
UNARY_OBJECT(index, PyNumber_Index)

#undef BINARY_OBJECT
#undef UNARY_OBJECT
uint64_t jacpy_power(uint64_t a, uint64_t b, int64_t inplace) {
    return HANDLE(inplace ? PyNumber_InPlacePower(OBJECT(a), OBJECT(b), Py_None)
                          : PyNumber_Power(OBJECT(a), OBJECT(b), Py_None));
}
uint64_t jacpy_boolean(int64_t value) { return HANDLE(PyBool_FromLong(value)); }
int64_t jacpy_is_none(uint64_t a) { return OBJECT(a) == Py_None; }
uint64_t jacpy_compare(uint64_t a, uint64_t b, int64_t operation) {
    return HANDLE(PyObject_RichCompare(OBJECT(a), OBJECT(b), (int)operation));
}
int64_t jacpy_contains(uint64_t a, uint64_t b) { return PySequence_Contains(OBJECT(a), OBJECT(b)); }
int64_t jacpy_sequence_index(uint64_t a, uint64_t b) { return PySequence_Index(OBJECT(a), OBJECT(b)); }
int64_t jacpy_sequence_count(uint64_t a, uint64_t b) { return PySequence_Count(OBJECT(a), OBJECT(b)); }
int64_t jacpy_length_hint(uint64_t a, int64_t fallback) { return PyObject_LengthHint(OBJECT(a), fallback); }
int64_t jacpy_setitem(uint64_t a, uint64_t b, uint64_t value) { return PyObject_SetItem(OBJECT(a), OBJECT(b), OBJECT(value)); }
int64_t jacpy_delitem(uint64_t a, uint64_t b) { return PyObject_DelItem(OBJECT(a), OBJECT(b)); }
uint64_t jacpy_getattr(uint64_t a, uint64_t name) { return HANDLE(PyObject_GetAttr(OBJECT(a), OBJECT(name))); }
uint64_t jacpy_call(uint64_t callable, uint64_t args, uint64_t kwargs) {
    return HANDLE(PyObject_Call(OBJECT(callable), OBJECT(args), OBJECT(kwargs)));
}
uint64_t jacpy_tuple_slice(uint64_t a, int64_t start, int64_t end) { return HANDLE(PyTuple_GetSlice(OBJECT(a), start, end)); }
int64_t jacpy_is_unicode(uint64_t a) { return PyUnicode_Check(OBJECT(a)); }
uint64_t jacpy_repr(uint64_t a) { return HANDLE(PyObject_Repr(OBJECT(a))); }
int64_t jacpy_repr_enter(uint64_t a) { return Py_ReprEnter(OBJECT(a)); }
void jacpy_repr_leave(uint64_t a) { Py_ReprLeave(OBJECT(a)); }
uint64_t jacpy_unicode_split(uint64_t a, uint64_t sep) { return HANDLE(PyUnicode_Split(OBJECT(a), OBJECT(sep), -1)); }
uint64_t jacpy_unicode_join(uint64_t sep, uint64_t items) { return HANDLE(PyUnicode_Join(OBJECT(sep), OBJECT(items))); }
int64_t jacpy_dict_size(uint64_t a) { return a ? PyDict_Size(OBJECT(a)) : 0; }
uint64_t jacpy_import_attr(const char *module, const char *name) { return HANDLE(PyImport_ImportModuleAttrString(module, name)); }
uint64_t jacpy_dict_entry(uint64_t a, int64_t position) {
    Py_ssize_t pos = position;
    PyObject *key, *value;
    if (!PyDict_Next(OBJECT(a), &pos, &key, &value)) return 0;
    return HANDLE(Py_BuildValue("nOO", pos, key, value));
}
#include <openssl/crypto.h>
int64_t jacpy_crypto_compare(uint64_t a, uint64_t b, int64_t size) {
    return CRYPTO_memcmp((const void *)(uintptr_t)a, (const void *)(uintptr_t)b, size);
}

/* Portable CPython wait primitives. Queue policy stays in Jac; only the wait
 * releases the GIL, and it restores it before touching any native state. */
#include "internal/pycore_time.h"
uint64_t jacpy_lock_new(void) {
    PyThread_type_lock lock = PyThread_allocate_lock();
    if (!lock) { PyErr_NoMemory(); return 0; }
    PyThread_acquire_lock(lock, WAIT_LOCK);
    return (uint64_t)(uintptr_t)lock;
}
void jacpy_lock_free(uint64_t handle) {
    PyThread_type_lock lock = (PyThread_type_lock)(uintptr_t)handle;
    PyThread_acquire_lock(lock, NOWAIT_LOCK);
    PyThread_release_lock(lock);
    PyThread_free_lock(lock);
}
void jacpy_lock_notify(uint64_t handle) { PyThread_release_lock((PyThread_type_lock)(uintptr_t)handle); }
int64_t jacpy_lock_wait(uint64_t handle, int64_t timeout_ns) {
    PyTime_t timeout_us = timeout_ns < 0 ? -1 : _PyTime_AsMicroseconds(timeout_ns, _PyTime_ROUND_CEILING);
    PyLockStatus status;
    Py_BEGIN_ALLOW_THREADS
    status = PyThread_acquire_lock_timed((PyThread_type_lock)(uintptr_t)handle, timeout_us, 1);
    Py_END_ALLOW_THREADS
    return status == PY_LOCK_ACQUIRED ? 1 : (status == PY_LOCK_INTR ? -1 : 0);
}
int64_t jacpy_pending_calls(void) { return Py_MakePendingCalls(); }
int64_t jacpy_timeout_ns(uint64_t value) {
    PyTime_t timeout;
    if (_PyTime_FromSecondsObject(&timeout, OBJECT(value), _PyTime_ROUND_CEILING) < 0) return -1;
    return timeout;
}
int64_t jacpy_deadline(int64_t timeout) { return _PyDeadline_Init(timeout); }
int64_t jacpy_deadline_remaining(int64_t deadline) { return _PyDeadline_Get(deadline); }
void jacpy_set_none_exception(uint64_t kind) { PyErr_SetNone(OBJECT(kind)); }

/* Unicode builders and exact container operations used by native serializers. */
uint64_t jacpy_writer_new(void) { return (uint64_t)(uintptr_t)PyUnicodeWriter_Create(0); }
void jacpy_writer_discard(uint64_t writer) { PyUnicodeWriter_Discard((PyUnicodeWriter *)(uintptr_t)writer); }
uint64_t jacpy_writer_finish(uint64_t writer) { return HANDLE(PyUnicodeWriter_Finish((PyUnicodeWriter *)(uintptr_t)writer)); }
int64_t jacpy_writer_char(uint64_t writer, int64_t value) { return PyUnicodeWriter_WriteChar((PyUnicodeWriter *)(uintptr_t)writer, (Py_UCS4)value); }
int64_t jacpy_writer_text(uint64_t writer, uint64_t text) { return PyUnicodeWriter_WriteStr((PyUnicodeWriter *)(uintptr_t)writer, OBJECT(text)); }
int64_t jacpy_writer_slice(uint64_t writer, uint64_t text, int64_t start, int64_t end) { return PyUnicodeWriter_WriteSubstring((PyUnicodeWriter *)(uintptr_t)writer, OBJECT(text), start, end); }
int64_t jacpy_writer_ascii(uint64_t writer, const char *text, int64_t size) { return PyUnicodeWriter_WriteASCII((PyUnicodeWriter *)(uintptr_t)writer, text, size); }
int64_t jacpy_unicode_size(uint64_t text) { return PyUnicode_GET_LENGTH(OBJECT(text)); }
int64_t jacpy_unicode_char(uint64_t text, int64_t index) { return PyUnicode_ReadChar(OBJECT(text), index); }
uint64_t jacpy_unicode_from_ordinal(int64_t point) { return HANDLE(PyUnicode_FromOrdinal((int)point)); }
uint64_t jacpy_unicode_decode_bytes(uint64_t value, const char *encoding) { return HANDLE(PyUnicode_FromEncodedObject(OBJECT(value), encoding, "strict")); }
uint64_t jacpy_unicode_slice(uint64_t text, int64_t start, int64_t end) { return HANDLE(PyUnicode_Substring(OBJECT(text), start, end)); }
uint64_t jacpy_dict_default(uint64_t dictionary, uint64_t key, uint64_t value) {
    PyObject *result;
    return PyDict_SetDefaultRef(OBJECT(dictionary), OBJECT(key), OBJECT(value), &result) < 0 ? 0 : HANDLE(result);
}
int64_t jacpy_dict_set(uint64_t dictionary, uint64_t key, uint64_t value) { return PyDict_SetItem(OBJECT(dictionary), OBJECT(key), OBJECT(value)); }
extern PyObject *jacpy_exception_type(const char *);
void jacpy_raise_value(const char *kind, uint64_t value) {
    PyObject *type = jacpy_exception_type(kind);
    if (type) PyErr_SetObject(type, OBJECT(value));
}
void jacpy_set_object_exception(uint64_t kind, uint64_t value) { PyErr_SetObject(OBJECT(kind), OBJECT(value)); }
int64_t jacpy_is_bool(uint64_t value) { return PyBool_Check(OBJECT(value)); }
int64_t jacpy_is_float(uint64_t value) { return PyFloat_Check(OBJECT(value)); }
int64_t jacpy_is_dict(uint64_t value) { return PyDict_Check(OBJECT(value)); }
int64_t jacpy_is_exact_dict(uint64_t value) { return PyDict_CheckExact(OBJECT(value)); }
uint64_t jacpy_long_repr(uint64_t value) { return HANDLE(PyLong_Type.tp_repr(OBJECT(value))); }
uint64_t jacpy_float_repr(uint64_t value) { return HANDLE(PyFloat_Type.tp_repr(OBJECT(value))); }
uint64_t jacpy_identity(uint64_t value) { return HANDLE(PyLong_FromVoidPtr(OBJECT(value))); }
uint64_t jacpy_type_name(uint64_t value) { return HANDLE(PyUnicode_FromString(Py_TYPE(OBJECT(value))->tp_name)); }
uint64_t jacpy_qualified_type_name(uint64_t value) { return HANDLE(PyType_GetFullyQualifiedName(Py_TYPE(OBJECT(value)))); }
uint64_t jacpy_error_take(void) { return HANDLE(PyErr_GetRaisedException()); }
void jacpy_error_restore(uint64_t value) { PyErr_SetRaisedException(OBJECT(value)); }
int64_t jacpy_exception_note(uint64_t error, uint64_t note) {
    PyObject *result = PyObject_CallMethod(OBJECT(error), "add_note", "O", OBJECT(note));
    if (!result) return -1;
    Py_DECREF(result); return 0;
}
uint64_t jacpy_sequence_fast(uint64_t value, const char *message) { return HANDLE(PySequence_Fast(OBJECT(value), message)); }
int64_t jacpy_fast_size(uint64_t value) { return PySequence_Fast_GET_SIZE(OBJECT(value)); }
uint64_t jacpy_fast_item(uint64_t value, int64_t index) { return HANDLE(Py_NewRef(PySequence_Fast_GET_ITEM(OBJECT(value), index))); }
uint64_t jacpy_mapping_items(uint64_t value) { return HANDLE(PyMapping_Items(OBJECT(value))); }
int64_t jacpy_list_sort(uint64_t value) { return PyList_Sort(OBJECT(value)); }
int64_t jacpy_dict_remove(uint64_t dictionary, uint64_t key) { return PyDict_DelItem(OBJECT(dictionary), OBJECT(key)); }
uint64_t jacpy_unicode_concat(uint64_t left, uint64_t right) { return HANDLE(PyUnicode_Concat(OBJECT(left), OBJECT(right))); }
uint64_t jacpy_sequence_repeat(uint64_t value, int64_t count) { return HANDLE(PySequence_Repeat(OBJECT(value), count)); }

/* Protocol primitives shared by native streaming and container modules. */
int64_t jacpy_is_exact_long(uint64_t value) { return PyLong_CheckExact(OBJECT(value)); }
int64_t jacpy_type_check(uint64_t value, uint64_t type) { return PyObject_TypeCheck(OBJECT(value), (PyTypeObject *)OBJECT(type)); }
int64_t jacpy_long_as_int32(uint64_t value) { return PyLong_AsInt(OBJECT(value)); }
uint64_t jacpy_getattr_string(uint64_t value, const char *name) { return HANDLE(PyObject_GetAttrString(OBJECT(value), name)); }
uint64_t jacpy_dict_get(uint64_t dictionary, uint64_t key) {
    PyObject *value;
    return PyDict_GetItemRef(OBJECT(dictionary), OBJECT(key), &value) < 0 ? 0 : HANDLE(value);
}
uint64_t jacpy_dict_keys(uint64_t dictionary) { return HANDLE(PyDict_Keys(OBJECT(dictionary))); }
int64_t jacpy_dict_pop_discard(uint64_t dictionary, uint64_t key) { return PyDict_Pop(OBJECT(dictionary), OBJECT(key), NULL); }
uint64_t jacpy_iter(uint64_t value) { return HANDLE(PyObject_GetIter(OBJECT(value))); }
uint64_t jacpy_iter_next(uint64_t value) { return HANDLE(PyIter_Next(OBJECT(value))); }
uint64_t jacpy_number_float(uint64_t value) { return HANDLE(PyNumber_Float(OBJECT(value))); }
int64_t jacpy_number_check(uint64_t value) { return PyNumber_Check(OBJECT(value)); }
uint64_t jacpy_object_str(uint64_t value) { return HANDLE(PyObject_Str(OBJECT(value))); }

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
int64_t jacpy_memory_byte(uint64_t address, int64_t offset) { return ((unsigned char *)(uintptr_t)address)[offset]; }
void jacpy_memory_set(uint64_t address, int64_t offset, int64_t value) { ((unsigned char *)(uintptr_t)address)[offset] = (unsigned char)value; }
void jacpy_memory_zero(uint64_t address, int64_t size) { memset((void *)(uintptr_t)address, 0, (size_t)size); }
void jacpy_memory_copy(uint64_t target, uint64_t source, int64_t size) { memcpy((void *)(uintptr_t)target, (void *)(uintptr_t)source, (size_t)size); }
void jacpy_memory_move(uint64_t target, uint64_t source, int64_t size) { memmove((void *)(uintptr_t)target, (void *)(uintptr_t)source, (size_t)size); }
uint64_t jacpy_bytearray_new(int64_t size) { return HANDLE(PyByteArray_FromStringAndSize(NULL, size)); }
int64_t jacpy_bytearray_resize(uint64_t value, int64_t size) { return PyByteArray_Resize(OBJECT(value), size); }
int64_t jacpy_bytearray_memory(uint64_t value) { return PyByteArray_Type.tp_basicsize + ((PyByteArrayObject *)OBJECT(value))->ob_alloc; }
uint64_t jacpy_float32_bits(double value) { float number = (float)value; uint32_t bits; memcpy(&bits, &number, sizeof(bits)); return bits; }
uint64_t jacpy_bytes_from_memory(uint64_t address, int64_t size) { return HANDLE(PyBytes_FromStringAndSize((const char *)(uintptr_t)address, size)); }
int64_t jacpy_is_bytes(uint64_t value) { return PyBytes_Check(OBJECT(value)); }
int64_t jacpy_is_bytearray(uint64_t value) { return PyByteArray_Check(OBJECT(value)); }
uint64_t jacpy_bytes_address(uint64_t value) { return (uint64_t)(uintptr_t)(PyBytes_Check(OBJECT(value)) ? PyBytes_AS_STRING(OBJECT(value)) : PyByteArray_AS_STRING(OBJECT(value))); }
int64_t jacpy_bytes_length(uint64_t value) { return PyBytes_Check(OBJECT(value)) ? PyBytes_GET_SIZE(OBJECT(value)) : PyByteArray_GET_SIZE(OBJECT(value)); }
int64_t jacpy_index_check(uint64_t value) { return PyIndex_Check(OBJECT(value)); }
uint64_t jacpy_long_pointer(uint64_t value) { return (uint64_t)(uintptr_t)PyLong_AsVoidPtr(OBJECT(value)); }
uint64_t jacpy_uint(uint64_t value) { return HANDLE(PyLong_FromUnsignedLongLong(value)); }
uint64_t jacpy_long_u64(uint64_t value) { return PyLong_AsUnsignedLongLong(OBJECT(value)); }
uint64_t jacpy_float(double value) { return HANDLE(PyFloat_FromDouble(value)); }
uint64_t jacpy_complex_value(uint64_t value) {
    Py_complex number = PyComplex_AsCComplex(OBJECT(value));
    if (PyErr_Occurred()) return 0;
    return HANDLE(PyComplex_FromCComplex(number));
}
double jacpy_complex_real(uint64_t value) { return PyComplex_RealAsDouble(OBJECT(value)); }
double jacpy_complex_imag(uint64_t value) { return PyComplex_ImagAsDouble(OBJECT(value)); }
uint64_t jacpy_complex(double real, double imaginary) { return HANDLE(PyComplex_FromDoubles(real, imaginary)); }
int64_t jacpy_float_pack(double value, uint64_t address, int64_t size, int64_t little) {
    char *target = (char *)(uintptr_t)address;
    if (size == 2) return PyFloat_Pack2(value, target, (int)little);
    if (size == 4) return PyFloat_Pack4(value, target, (int)little);
    return PyFloat_Pack8(value, target, (int)little);
}
double jacpy_float_unpack(uint64_t address, int64_t size, int64_t little) {
    const char *source = (const char *)(uintptr_t)address;
    if (size == 2) return PyFloat_Unpack2(source, (int)little);
    if (size == 4) return PyFloat_Unpack4(source, (int)little);
    return PyFloat_Unpack8(source, (int)little);
}
void jacpy_native_float_store(double value, uint64_t address, int64_t size) {
    if (size == 4) { float number = (float)value; memcpy((void *)(uintptr_t)address, &number, sizeof(number)); }
    else memcpy((void *)(uintptr_t)address, &value, sizeof(value));
}

void jacpy_dict_clear(uint64_t value) { PyDict_Clear(OBJECT(value)); }

double jacpy_number_as_double(uint64_t value) { return PyFloat_AsDouble(OBJECT(value)); }

void jacpy_clear_errno(void) { errno = 0; }
int64_t jacpy_math_errno(void) { return errno == EDOM ? 1 : errno == ERANGE ? 2 : 0; }

int64_t jacpy_compare_bool(uint64_t a, uint64_t b, int64_t operation) {
    return PyObject_RichCompareBool(OBJECT(a), OBJECT(b), (int)operation);
}
void jacpy_set_key_error(uint64_t key) {
    PyObject *args = PyTuple_Pack(1, OBJECT(key));
    if (args) { PyErr_SetObject(PyExc_KeyError, args); Py_DECREF(args); }
}

uint64_t jacpy_dict_repr(uint64_t value) { return HANDLE(PyDict_Type.tp_repr(OBJECT(value))); }

uint64_t jacpy_sequence_list(uint64_t value) { return HANDLE(PySequence_List(OBJECT(value))); }

int64_t jacpy_long_sign(uint64_t value) {
    PyLongObject *integer = (PyLongObject *)OBJECT(value);
    return _PyLong_IsNegative(integer) ? -1 : _PyLong_IsZero(integer) ? 0 : 1;
}
uint64_t jacpy_long_gcd(uint64_t a, uint64_t b) { return HANDLE(_PyLong_GCD(OBJECT(a), OBJECT(b))); }
uint64_t jacpy_long_shift(uint64_t value, int64_t count, int64_t left) {
    return HANDLE(left ? _PyLong_Lshift(OBJECT(value), count) : _PyLong_Rshift(OBJECT(value), count));
}

uint64_t jacpy_special_noargs(uint64_t value, const char *name) {
    PyObject *key=PyUnicode_InternFromString(name);
    if(!key) return 0;
    PyObject *method=_PyObject_LookupSpecial(OBJECT(value),key); Py_DECREF(key);
    if(!method) return 0;
    PyObject *result=PyObject_CallNoArgs(method); Py_DECREF(method); return HANDLE(result);
}
uint64_t jacpy_long_from_double(double value) { return HANDLE(PyLong_FromDouble(value)); }
uint64_t jacpy_libm_parts(double value, int64_t integral) {
    if(integral) { double whole; double fraction=modf(value,&whole); return HANDLE(Py_BuildValue("dd",fraction,whole)); }
    int exponent=0; double fraction=frexp(value,&exponent); return HANDLE(Py_BuildValue("di",fraction,exponent));
}
uint64_t jacpy_float_bits(double value) { uint64_t bits; memcpy(&bits,&value,sizeof(bits)); return bits; }
double jacpy_float_from_bits(uint64_t bits) { double value; memcpy(&value,&bits,sizeof(value)); return value; }
uint64_t jacpy_long_frexp(uint64_t value) {
    int64_t exponent; double fraction=_PyLong_Frexp((PyLongObject *)OBJECT(value),&exponent);
    return PyErr_Occurred() ? 0 : HANDLE(Py_BuildValue("dL",fraction,(long long)exponent));
}

double jacpy_long_double(uint64_t value) { return PyLong_AsDouble(OBJECT(value)); }

uint64_t jacpy_sequence_tuple(uint64_t value) { return HANDLE(PySequence_Tuple(OBJECT(value))); }
int64_t jacpy_is_exact_float(uint64_t value) { return PyFloat_CheckExact(OBJECT(value)); }

int64_t jacpy_long_fits_i64(uint64_t value) { int overflow; (void)PyLong_AsLongLongAndOverflow(OBJECT(value),&overflow); return overflow == 0; }

/* Retained object primitives used by native callable and cache policies. */
uint64_t jacpy_call_two(uint64_t callable, uint64_t a, uint64_t b) {
    PyObject *args[] = {OBJECT(a), OBJECT(b)};
    return HANDLE(PyObject_Vectorcall(OBJECT(callable), args, 2, NULL));
}
uint64_t jacpy_object_type(uint64_t value) { return HANDLE(Py_NewRef(Py_TYPE(OBJECT(value)))); }
int64_t jacpy_callable(uint64_t value) { return PyCallable_Check(OBJECT(value)); }
int64_t jacpy_is_exact_unicode(uint64_t value) { return PyUnicode_CheckExact(OBJECT(value)); }
int64_t jacpy_is_exact_tuple(uint64_t value) { return PyTuple_CheckExact(OBJECT(value)); }
int64_t jacpy_object_hash(uint64_t value) { return PyObject_Hash(OBJECT(value)); }
uint64_t jacpy_dict_copy(uint64_t value) { return HANDLE(PyDict_Copy(OBJECT(value))); }
int64_t jacpy_dict_update(uint64_t target, uint64_t source) { return PyDict_Update(OBJECT(target), OBJECT(source)); }
uint64_t jacpy_ordered_dict_new(void) { return HANDLE(PyObject_CallNoArgs((PyObject *)&PyODict_Type)); }

int64_t jacpy_tuple_unique(uint64_t value) { return Py_REFCNT(OBJECT(value)) == 1; }
/* Exchange is valid only after the native caller has established exclusive
 * ownership. It returns the old reference without invoking a finalizer. */
uint64_t jacpy_tuple_exchange(uint64_t value, int64_t index, uint64_t item) {
    PyObject *tuple=OBJECT(value), *old=PyTuple_GET_ITEM(tuple,index);
    PyTuple_SET_ITEM(tuple,index,Py_NewRef(OBJECT(item)));
    if(!PyObject_GC_IsTracked(tuple)) PyObject_GC_Track(tuple);
    return HANDLE(old);
}

/* Retained object primitives used by native wire protocols. */
uint64_t jacpy_number_long(uint64_t value) { return HANDLE(PyNumber_Long(OBJECT(value))); }
uint64_t jacpy_long_signed_bytes(uint64_t value, int64_t size) {
    PyObject *result = PyBytes_FromStringAndSize(NULL, size);
    if (!result) return 0;
    if (_PyLong_AsByteArray((PyLongObject *)OBJECT(value), (unsigned char *)PyBytes_AS_STRING(result), size, 1, 1, 1) < 0) {
        Py_DECREF(result); return 0;
    }
    return HANDLE(result);
}
uint64_t jacpy_long_from_signed_bytes(uint64_t value) {
    return HANDLE(_PyLong_FromByteArray((const unsigned char *)PyBytes_AS_STRING(OBJECT(value)), PyBytes_GET_SIZE(OBJECT(value)), 1, 1));
}
uint64_t jacpy_bytes_decode(uint64_t value, const char *encoding, const char *errors) {
    return HANDLE(PyUnicode_Decode(PyBytes_AS_STRING(OBJECT(value)), PyBytes_GET_SIZE(OBJECT(value)), encoding, errors));
}
uint64_t jacpy_unicode_encode(uint64_t value, const char *encoding, const char *errors) { return HANDLE(PyUnicode_AsEncodedString(OBJECT(value), encoding, errors)); }
uint64_t jacpy_optional_attr(uint64_t value, const char *name) { PyObject *result = NULL; return PyObject_GetOptionalAttrString(OBJECT(value), name, &result) < 0 ? 0 : HANDLE(result); }
int64_t jacpy_setattr(uint64_t value, uint64_t name, uint64_t item) { return PyObject_SetAttr(OBJECT(value), OBJECT(name), OBJECT(item)); }
uint64_t jacpy_import_object(uint64_t name) { return HANDLE(PyImport_Import(OBJECT(name))); }
uint64_t jacpy_type_new(uint64_t type, uint64_t args, uint64_t kwargs) {
    if (!PyType_Check(OBJECT(type))) { PyErr_SetString(PyExc_TypeError, "NEWOBJ class argument must be a type"); return 0; }
    if (!PyTuple_Check(OBJECT(args))) { PyErr_SetString(PyExc_TypeError, "NEWOBJ args argument must be a tuple"); return 0; }
    if (kwargs && !PyDict_Check(OBJECT(kwargs))) { PyErr_SetString(PyExc_TypeError, "NEWOBJ_EX kwargs argument must be a dict"); return 0; }
    PyTypeObject *cls = (PyTypeObject *)OBJECT(type);
    if (!cls->tp_new) { PyErr_SetString(PyExc_TypeError, "NEWOBJ class has no __new__"); return 0; }
    return HANDLE(cls->tp_new(cls, OBJECT(args), OBJECT(kwargs)));
}

uint64_t jacpy_set_new(uint64_t iterable, int64_t frozen) { return HANDLE(frozen ? PyFrozenSet_New(OBJECT(iterable)) : PySet_New(OBJECT(iterable))); }
int64_t jacpy_set_add(uint64_t set, uint64_t value) { return PySet_Add(OBJECT(set), OBJECT(value)); }
uint64_t jacpy_memoryview(uint64_t value) { return HANDLE(PyMemoryView_FromObject(OBJECT(value))); }
int64_t jacpy_is_type(uint64_t value) { return PyType_Check(OBJECT(value)); }
uint64_t jacpy_float_from_text(uint64_t value) { return HANDLE(PyFloat_FromString(OBJECT(value))); }
uint64_t jacpy_bytes_unescape(uint64_t value) { return HANDLE(PyBytes_DecodeEscape(PyBytes_AS_STRING(OBJECT(value)), PyBytes_GET_SIZE(OBJECT(value)), "strict", 0, NULL)); }

/* Exact built-in categories: subclasses use their object protocols instead. */
static PyTypeObject *const builtin_types[] = {
    NULL, &PyBool_Type, &PyLong_Type, &PyFloat_Type, &PyBytes_Type,
    &PyUnicode_Type, &PyTuple_Type, &PyList_Type, &PyDict_Type, &PySet_Type,
    &PyFrozenSet_Type, &PyByteArray_Type, &PyType_Type, &PyFunction_Type,
    &PyPickleBuffer_Type
};
int64_t jacpy_builtin_kind(uint64_t value) {
    PyObject *object = OBJECT(value);
    if (object == Py_None) return 0;
    for (size_t i = 1; i < sizeof(builtin_types) / sizeof(*builtin_types); ++i)
        if (Py_TYPE(object) == builtin_types[i]) return (int64_t)i;
    return 15;
}
uint64_t jacpy_builtin_type(int64_t kind) {
    if (kind == 0) return HANDLE(Py_NewRef((PyObject *)Py_TYPE(Py_None)));
    if (kind < 0 || (uint64_t)kind >= sizeof(builtin_types) / sizeof(*builtin_types)) {
        PyErr_SetString(PyExc_SystemError, "invalid built-in type category"); return 0;
    }
    return HANDLE(Py_NewRef((PyObject *)builtin_types[kind]));
}
uint64_t jacpy_generic_getattr(uint64_t object, uint64_t name) {
    return HANDLE(PyObject_GenericGetAttr(OBJECT(object), OBJECT(name)));
}
int32_t jacpy_generic_setattr(uint64_t object, uint64_t name, uint64_t value) {
    return PyObject_GenericSetAttr(OBJECT(object), OBJECT(name), OBJECT(value));
}

int64_t jacpy_is_not_implemented(uint64_t value) { return OBJECT(value) == Py_NotImplemented; }

int64_t jacpy_audit_pickle_find(uint64_t module, uint64_t name) { return PySys_Audit("pickle.find_class", "OO", OBJECT(module), OBJECT(name)); }

uint64_t jacpy_mapping_optional_item(uint64_t mapping, uint64_t key) { PyObject *result = NULL; return PyMapping_GetOptionalItem(OBJECT(mapping), OBJECT(key), &result) < 0 ? 0 : HANDLE(result); }

int64_t jacpy_is_iterator(uint64_t value) { return PyIter_Check(OBJECT(value)); }

uint64_t jacpy_not_implemented(void) { return HANDLE(Py_NewRef(Py_NotImplemented)); }
uint64_t jacpy_ellipsis(void) { return HANDLE(Py_NewRef(Py_Ellipsis)); }

void jacpy_exception_context(uint64_t error, uint64_t cause) { PyException_SetContext(OBJECT(error), Py_NewRef(OBJECT(cause))); }

uint64_t jacpy_dict_items(uint64_t value) { return HANDLE(PyDict_Items(OBJECT(value))); }
uint64_t jacpy_unicode_intern(uint64_t value) { PyObject *result=Py_NewRef(OBJECT(value)); PyUnicode_InternInPlace(&result); return HANDLE(result); }

int64_t jacpy_dict_memory(uint64_t value) {
    PyObject *size = PyObject_CallMethod(OBJECT(value), "__sizeof__", NULL);
    if (!size) return -1;
    Py_ssize_t result = PyLong_AsSsize_t(size);
    Py_DECREF(size);
    return result;
}

/* General value conversion and interpreter services for native bindings. */
int64_t jacpy_is_slice(uint64_t value) { return PySlice_Check(OBJECT(value)); }
typedef struct { int64_t start, stop, step, count, valid; } JacSliceBounds;
JacSliceBounds jacpy_slice_unpack(uint64_t value) {
    JacSliceBounds result = {0};
    Py_ssize_t start, stop, step;
    if (PySlice_Unpack(OBJECT(value), &start, &stop, &step) == 0)
        result = (JacSliceBounds){start, stop, step, 0, 1};
    return result;
}
JacSliceBounds jacpy_slice_adjust(int64_t length, JacSliceBounds bounds) {
    Py_ssize_t start = bounds.start, stop = bounds.stop;
    bounds.count = PySlice_AdjustIndices(length, &start, &stop, bounds.step);
    bounds.start = start; bounds.stop = stop;
    return bounds;
}
int64_t jacpy_audit(const char *event, uint64_t arguments) { return PySys_AuditTuple(event, OBJECT(arguments)); }
int64_t jacpy_warn(const char *category, const char *message, int64_t stacklevel) {
    extern PyObject *jacpy_exception_type(const char *);
    return PyErr_WarnEx(jacpy_exception_type(category), message, stacklevel);
}
uint64_t jacpy_builtins(void) { return HANDLE(Py_NewRef(PyEval_GetBuiltins())); }
int64_t jacpy_type_subtype(uint64_t type, uint64_t base) { return PyType_IsSubtype((PyTypeObject *)OBJECT(type), (PyTypeObject *)OBJECT(base)); }
