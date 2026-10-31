"""Generate jac/jaclang/runtime/python/cpython_api.jac from the C API headers.

Native Jac modules call the CPython C API by its own names. This script reads
every declaration of the C API table (capi_table.jac: the PyAPI_FUNC and
PyAPI_DATA declarations of the generated headers and the plain `extern` ones
of the internal headers, which gen_include.jac writes into the headers) and
emits a typed clib declaration for each function the JacPython sources use,
so Jac code reads like the C it replaces:

    jac run scripts/jacpython/gen_capi.jac            # rewrite the file
    jac run scripts/jacpython/gen_capi.jac --check    # fail on drift

Exported functions and data symbols are declared. A variadic function's `...`
is `*args: any`, so a call passes its extra arguments with C's default
promotions (`PyTuple_Pack(2, a, b)`). A PyAPI_DATA variable (or
an internal header's `extern` one) becomes a `glob` of the clib block: an
object pointer such as `PyExc_TypeError` is read in place as ptr[PyObject],
and a C object such as `PyLong_Type` is declared with the opaque PyObject type
and used by address, `addressof(PyLong_Type)`. `Py_None`, `Py_NotImplemented`
and `Py_Ellipsis`, macros for such an address, are globs of it. Other macros
and static inline helpers have no linkable symbol; capi.jac expresses them
through exported functions and the C helpers. A use of a name that is not
declared here is an ordinary unresolved-name error from `jac check`.
"""
import argparse;
import re;
import sys;
import from pathlib { Path }
import from common { REPO, RUNTIME, SOURCES, format_jac, pin, write_or_check }
import from capi_table { DECLARATIONS }

glob OUTPUT: Path = RUNTIME / "cpython_api.jac",
     # The jacpy_* helpers for what has no exported function (macros, struct
     # fields, errno): their C prototypes, a C string as `const char *`. The
     # helpers are Jac definitions (runtime/python/object_model/object_api.jac
     # and compiler_objects.jac); these declare them to their callers.
     HELPER_PROTOTYPES: list[str] = [
         "typedef struct {int64_t start, stop, step, count, valid;} SliceBounds;",
         "void * jacpy_sequence_slot(PyObject *handle) {",
         "int64_t jacpy_less(PyObject *left, PyObject *right) {",
         "int64_t jacpy_recursion_enter(const char *context) {",
         "int64_t jacpy_list_size(PyObject *handle) {",
         "int64_t jacpy_list_delete(PyObject *handle, int64_t start, int64_t end) {",
         "PyObject * jacpy_list_exchange(PyObject *handle, int64_t index, PyObject *value) {",
         "void jacpy_list_swap(PyObject *handle, int64_t left, int64_t right) {",
         "void * jacpy_comparison_slot(PyObject *handle) {",
         "int64_t jacpy_same_type(PyObject *left, PyObject *right) {",
         "int64_t jacpy_is_long(PyObject *handle) {",
         "PyObject * jacpy_long_absolute(PyObject *handle) {",
         "PyObject * jacpy_hash_unsigned(PyObject *handle) {",
         "PyObject * jacpy_long_bytes(PyObject *handle, int64_t size) {",
         "PyObject * jacpy_long_from_bytes(PyObject *handle) {",
         "PyObject * jacpy_entropy(int64_t size) {",
         "int64_t jacpy_wall_time(void) {",
         "int64_t jacpy_monotonic_time(void) {",
         "int64_t jacpy_process_id(void) {",
         "int64_t jacpy_is_tuple(PyObject *handle) {",
         "PyObject * jacpy_tuple_item(PyObject *handle, int64_t index) {",
         "PyObject ** jacpy_tuple_items(PyObject *handle) {",
         "int64_t jacpy_tuple_set_owned(PyObject *handle, int64_t index, PyObject *value) {",
         "PyObject * jacpy_buffer_bytes(const Py_buffer *view) {",
         "Py_buffer * jacpy_buffer_acquire(PyObject *value, int64_t kind) {",
         "void jacpy_buffer_release(Py_buffer *value) {",
         "int64_t jacpy_unicode_ascii(PyObject *value) {",
         "void jacpy_set_exception(PyObject *type, const char *message, int64_t size) {",
         "PyObject * jacpy_power(PyObject *a, PyObject *b, int64_t inplace) {",
         "int64_t jacpy_is_unicode(PyObject *a) {",
         "PyObject * jacpy_unicode_split(PyObject *a, PyObject *sep) {",
         "int64_t jacpy_dict_size(PyObject *a) {",
         "int64_t jacpy_crypto_compare(const void *a, const void *b, int64_t size) {",
         "void * jacpy_lock_new(void) {",
         "void jacpy_lock_free(void *handle) {",
         "int64_t jacpy_lock_wait(void *handle, int64_t timeout_ns) {",
         "int64_t jacpy_timeout_ns(PyObject *value) {",
         "PyUnicodeWriter * jacpy_writer_new(void) {",
         "int64_t jacpy_unicode_size(PyObject *text) {",
         "int64_t jacpy_unicode_kind(PyObject *text) {",
         "void * jacpy_unicode_data(PyObject *text) {",
         "PyObject * jacpy_unicode_decode_bytes(PyObject *value, const char *encoding) {",
         "PyObject * jacpy_dict_default(PyObject *dictionary, PyObject *key, PyObject *value) {",
         "int64_t jacpy_is_bool(PyObject *value) {",
         "int64_t jacpy_is_float(PyObject *value) {",
         "int64_t jacpy_is_dict(PyObject *value) {",
         "int64_t jacpy_is_exact_dict(PyObject *value) {",
         "PyObject * jacpy_long_repr(PyObject *value) {",
         "PyObject * jacpy_float_repr(PyObject *value) {",
         "PyObject * jacpy_type_name(PyObject *value) {",
         "PyObject * jacpy_qualified_type_name(PyObject *value) {",
         "int64_t jacpy_fast_size(PyObject *value) {",
         "PyObject * jacpy_fast_item(PyObject *value, int64_t index) {",
         "int64_t jacpy_is_exact_long(PyObject *value) {",
         "int64_t jacpy_type_check(PyObject *value, PyObject *type) {",
         "PyObject * jacpy_dict_get(PyObject *dictionary, PyObject *key) {",
         "int64_t jacpy_dict_pop_discard(PyObject *dictionary, PyObject *key) {",
         "int64_t jacpy_native_size(int64_t kind, int64_t alignment) {",
         "int64_t jacpy_native_little_endian(void) {",
         "int64_t jacpy_char_max(void) {",
         "void jacpy_memory_zero(void *address, int64_t size) {",
         "void jacpy_memory_copy(void *target, void *source, int64_t size) {",
         "void jacpy_memory_move(void *target, void *source, int64_t size) {",
         "PyObject * jacpy_bytearray_new(int64_t size) {",
         "int64_t jacpy_bytearray_memory(PyObject *value) {",
         "uint64_t jacpy_float32_bits(double value) {",
         "PyObject * jacpy_bytes_from_memory(const void *address, int64_t size) {",
         "PyObject * jacpy_bytes_from_payload(const char *data, int64_t size) {",
         "int64_t jacpy_is_bytes(PyObject *value) {",
         "int64_t jacpy_is_bytearray(PyObject *value) {",
         "void * jacpy_bytes_address(PyObject *value) {",
         "int64_t jacpy_bytes_length(PyObject *value) {",
         "void jacpy_bytes_copy_to(PyObject *value, char *target, int64_t size) {",
         "PyObject * jacpy_complex_value(PyObject *value) {",
         "int64_t jacpy_float_pack(double value, void *address, int64_t size, int64_t little) {",
         "double jacpy_float_unpack(const void *address, int64_t size, int64_t little) {",
         "void jacpy_native_float_store(double value, void *address, int64_t size) {",
         "void jacpy_clear_errno(void) {",
         "int64_t jacpy_math_errno(void) {",
         "double jacpy_libm_log(double value) {",
         "double jacpy_libm_log2(double value) {",
         "double jacpy_libm_log10(double value) {",
         "double jacpy_libm_exp(double value) {",
         "double jacpy_libm_exp2(double value) {",
         "double jacpy_libm_sin(double value) {",
         "double jacpy_libm_cos(double value) {",
         "double jacpy_libm_tan(double value) {",
         "double jacpy_libm_fma(double x, double y, double z) {",
         "PyObject * jacpy_dict_repr(PyObject *value) {",
         "int64_t jacpy_long_sign(PyObject *value) {",
         "PyObject * jacpy_long_shift(PyObject *value, int64_t count, int64_t left) {",
         "PyObject * jacpy_special_noargs(PyObject *value, const char *name) {",
         "uint64_t jacpy_float_bits(double value) {",
         "double jacpy_float_from_bits(uint64_t bits) {",
         "int64_t jacpy_is_exact_float(PyObject *value) {",
         "int64_t jacpy_long_fits_i64(PyObject *value) {",
         "PyObject * jacpy_call_two(PyObject *callable, PyObject *a, PyObject *b) {",
         "PyObject * jacpy_object_type(PyObject *value) {",
         "int64_t jacpy_is_exact_unicode(PyObject *value) {",
         "int64_t jacpy_is_exact_tuple(PyObject *value) {",
         "int64_t jacpy_is_exact_list(PyObject *value) {",
         "int64_t jacpy_tuple_unique(PyObject *value) {",
         "PyObject * jacpy_tuple_exchange(PyObject *value, int64_t index, PyObject *item) {",
         "PyObject * jacpy_long_signed_bytes(PyObject *value, int64_t size) {",
         "PyObject * jacpy_long_from_signed_bytes(PyObject *value) {",
         "PyObject * jacpy_bytes_decode(PyObject *value, const char *encoding, const char *errors) {",
         "PyObject * jacpy_optional_attr(PyObject *value, const char *name) {",
         "PyObject * jacpy_type_new(PyObject *type, PyObject *args, PyObject *kwargs) {",
         "PyObject * jacpy_set_new(PyObject *iterable, int64_t frozen) {",
         "int64_t jacpy_is_type(PyObject *value) {",
         "PyObject * jacpy_bytes_unescape(PyObject *value) {",
         "PyObject * jacpy_mapping_optional_item(PyObject *mapping, PyObject *key) {",
         "void jacpy_exception_context(PyObject *error, PyObject *cause) {",
         "PyObject * jacpy_unicode_intern(PyObject *value) {",
         "int64_t jacpy_is_slice(PyObject *value) {",
         "int64_t jacpy_is_code(PyObject *value) {",
         "SliceBounds jacpy_slice_unpack(PyObject *value) {",
         "SliceBounds jacpy_slice_adjust(int64_t length, SliceBounds bounds) {",
         "PyObject * jacpy_builtins(void) {",
         "PyObject * jacpy_fs_text(const void *text) {",
         "PyMethodDef * jacpy_cfunction_method(PyObject *function) {",
         "PyObject * jacpy_cfunction_self(PyObject *function) {",
         "PyObject * jacpy_cfunction_module(PyObject *function) {",
         "PyObject * jacpy_struct_sequence_type(const char *name, const char *doc, const char *fields, int64_t visible) {",
         "PyObject ** jacpy_typing_types(void) {",
         "void ** jacpy_open_code_hook(void) {",
         "void ** jacpy_open_code_userdata(void) {",
         "int32_t jacpy_stdio_fileno(int32_t stream) {",
         "PyObject * jacpy_weakref_list(PyObject *object) {",
         "int64_t jacpy_remove_dead_weakref(PyObject *dictionary, PyObject *key) {",
         "PyObject ** jacpy_asyncio_running_loop(void) {",
         "PyObject ** jacpy_asyncio_running_task(void) {",
         "void * jacpy_asyncio_tasks_head(void) {",
         "PyObject * jacpy_asyncio_thread_task(PyObject *loop) {",
         "int64_t jacpy_asyncio_add_tasks(PyObject *tasks, int64_t node_offset, int64_t all_threads) {",
         "int64_t jacpy_errno(void) {",
         "void jacpy_set_errno(int64_t value) {",
         "void * jacpy_opendir(const char *path) {",
         "const char * jacpy_readdir_name(void *directory) {",
         "int32_t jacpy_dirfd(void *directory) {",
         "int32_t jacpy_closedir(void *directory) {",
         "void * jacpy_fdopendir(int32_t fd) {",
         "void jacpy_rewinddir(void *directory) {",
         "const char * jacpy_readdir_entry(void *directory, int64_t *type, uint64_t *inode) {",
         "int32_t jacpy_stat(const char *path, struct _Py_stat_struct *status) {",
         "int32_t jacpy_lstat(const char *path, struct _Py_stat_struct *status) {",
         "int32_t jacpy_fstat(int32_t fd, struct _Py_stat_struct *status) {",
         "int32_t jacpy_fstatat(int32_t dir_fd, const char *path, struct _Py_stat_struct *status, int32_t flags) {",
         "int32_t jacpy_statfs(const char *path, void *buffer) {",
         "int32_t jacpy_fstatfs(int32_t fd, void *buffer) {",
         "PyObject ** jacpy_fork_callbacks(PyInterpreterState *interp, int64_t which) {",
         "void jacpy_runtime_head_lock(void) {",
         "void jacpy_runtime_head_unlock(void) {",
         "void jacpy_thread_state_native_id(PyThreadState *tstate) {",
         "void jacpy_thread_state_fork_reset(PyThreadState *tstate) {",
         "int64_t jacpy_interpreter_finalizing(void) {",
         "int64_t jacpy_long_u64_checked(PyObject *value, uint64_t *out) {",
         "int64_t jacpy_unsigned_converter(PyObject *value, uint64_t *out, int64_t long_long) {",
         "uint64_t jacpy_long_address(PyObject *value) {",
         "int64_t jacpy_hacl_simd_features(void) {",
         "void jacpy_unicode_init_static_strings(PyInterpreterState *interp) {",
         "PyObject * jacpy_unicode_from_text(const char *text) {",
         "PyObject * jacpy_unicode_intern_text(const char *text) {",
         "int jacpy_unicode_equal_text(PyObject *op, const char *text) {",
         "int jacpy_unicode_writer_write_text(PyUnicodeWriter *writer, const char *text, Py_ssize_t size) {",
         "FILE * jacpy_stdio_stream(int32_t stream) {",
         "PyObject * jacpy_object_getattr_text(PyObject *op, const char *name) {",
         "int jacpy_object_setattr_text(PyObject *op, const char *name, PyObject *value) {",
         "int jacpy_object_getoptionalattr_text(PyObject *op, const char *name, PyObject **result) {",
         "int jacpy_module_add_object_ref_text(PyObject *mod, const char *name, PyObject *value) {",
         "int jacpy_module_add_text(PyObject *mod, const char *name, PyObject *value) {",
         "int jacpy_module_add_int_text(PyObject *mod, const char *name, long value) {",
         "int jacpy_module_add_string_text(PyObject *mod, const char *name, const char *value) {",
         "int jacpy_arg_parse_sized_text(PyObject *arg, const char *format, const char **data, Py_ssize_t *size) {",
         "int jacpy_audit_tuple_text(const char *event, PyObject *args) {",
         "intptr_t jacpy_stack_address(void *slots) {",
         "void * jacpy_va_list(void *va) {",
         "PyStatus jacpy_apple_streams(PyThreadState *tstate) {",
         "const char * jacpy_getpath_macro(int64_t which) {",
         "PyObject * jacpy_unicode_escape(const char *source, int64_t size) {",
         "PyObject * jacpy_bytes_escape(const char *source, int64_t size) {",
         "int64_t jacpy_buffer_size(PyObject *handle) {",
         "int64_t jacpy_buffer_byte(PyObject *handle, int64_t index) {",
         "void jacpy_release(PyObject *handle) {",
         "PyObject * jacpy_parse_long(const char *source, int64_t size) {",
         "PyObject * jacpy_parse_float(const char *source, int64_t size) {",
         "double jacpy_float_value(PyObject *handle) {",
         "int64_t jacpy_ast_kind(PyObject *handle) {",
         "PyObject * jacpy_ast_new(int64_t kind) {",
         "int64_t jacpy_set_owned(PyObject *target, int64_t field, PyObject *value) {",
         "PyObject * jacpy_field(PyObject *handle, int64_t field) {",
         "PyObject * jacpy_optional_field(PyObject *handle, int64_t field) {",
         "PyObject * jacpy_list_new(void) {",
         "int64_t jacpy_list_append_owned(PyObject *target, PyObject *value) {",
         "PyObject * jacpy_text(const char *value, int64_t size) {",
         "PyObject * jacpy_buffer_new(int64_t size) {",
         "void jacpy_buffer_set(PyObject *handle, int64_t index, int64_t value) {",
         "PyObject * jacpy_code_new(int64_t argcount, int64_t posonlyargcount, int64_t kwonlyargcount, int64_t stacksize, int64_t flags, PyObject *code, PyObject *consts, PyObject *names, PyObject *localsplusnames, PyObject *localspluskinds, PyObject *filename, PyObject *name, PyObject *qualname, int64_t firstlineno, PyObject *linetable, PyObject *exceptiontable) {",
         "int64_t jacpy_value_kind(PyObject *handle) {",
         "PyObject * jacpy_marshal(PyObject *handle) {",
         "PyObject * jacpy_utf8(PyObject *handle) {",
         "int64_t jacpy_sequence_size(PyObject *handle) {",
         "PyObject * jacpy_sequence_item(PyObject *handle, int64_t index) {",
         "int64_t jacpy_is_list(PyObject *handle) {",
         "int64_t jacpy_error_pending(void) {",
         "PyObject * jacpy_decode(PyObject *handle, const char *encoding) {",
         "PyObject * jacpy_take_error_text(void) {",
         "PyObject * jacpy_symtable_entry(PyObject *name, int64_t kind, int64_t lineno, int64_t nested, PyObject *symbols, PyObject *varnames, PyObject *children) {",
         "int64_t jacpy_dict_set_owned(PyObject *dictionary, PyObject *key, PyObject *value) {",
         "PyObject * jacpy_readline(PyObject *reader, const char *encoding, int64_t decode) {",
         "PyObject * jacpy_source_bytes(PyObject *handle) {",
         "int64_t jacpy_source_kind(PyObject *handle) {",
         "int64_t jacpy_codec_valid(const char *name) {",
         "PyObject * jacpy_fd_line(int64_t fd) {",
         "PyObject ** jacpy_atexit_callbacks(PyInterpreterState *interp) {",
         "int32_t jacpy_atexit_push(PyInterpreterState *interp, void *func, void *data) {",
         "atexit_callback * jacpy_atexit_detach(PyInterpreterState *interp) {"
     ];

# Opaque C types a declaration may point to. Each becomes `obj Name;` and is
# usable only as ptr[Name]. Every object layout that begins with a PyObject
# header is declared as ptr[PyObject], matching the casts CPython's own C makes;
# the remaining opaque types are not Python objects.
glob OPAQUE: list[str] = [
         "PyObject",
         "PyThreadState",
         "PyInterpreterState",
         "PyUnicodeWriter",
         "PyModuleDef",
         "PyCompilerFlags",
         "PyBytesWriter",
         "PyMutex",
         "_Py_freelists",
         "PyLongWriter",
         "_PyUnicodeWriter",
         "_PyRuntimeState",
         "FILE"
     ],
     OBJECT_LAYOUTS: set[str] = {
         "PyTypeObject",
         "PyLongObject",
         "PyCodeObject",
         "PyFrameObject",
         "PyDictObject",
         "PyListObject",
         "PyTupleObject",
         "PyBytesObject",
         "PyVarObject",
         "PyUnicodeObject",
         "PyFloatObject",
         "PyByteArrayObject",
         "PySetObject",
         "PySTEntryObject",
         "PyWeakReference",
         "PyFunctionObject",
         "PyGenObject"
     },
     # Field names differ from C where C's are Jac keywords; layout is by position.
     STRUCTS: dict[str, str] = {
         "Py_complex": "obj Py_complex { has real: f64, imag: f64; }",
         "PyMethodDef": (
             "obj PyMethodDef { has ml_name: ptr[u8], ml_meth: ptr, ml_flags: i32, "
             + "ml_doc: ptr[u8]; }"
         ),
         "Py_buffer": (
             "obj Py_buffer { has buf: ptr, owner: ptr[PyObject], length: i64, itemsize: i64, "
             + "readonly: i32, ndim: i32, format_: ptr[u8], shape: ptr[i64], strides: ptr[i64], "
             + "suboffsets: ptr[i64], internal: ptr; }"
         ),
         "PyMemberDef": (
             "obj PyMemberDef { has name: ptr[u8] = ptr[u8](), type_: i32 = 0, "
             + "offset: i64 = 0, flags: i32 = 0, doc: ptr[u8] = ptr[u8](); }"
         ),
         # PyLong_Export() and PyLong_GetNativeLayout() (Include/cpython/longintrepr.h).
         "PyLongExport": (
             "obj PyLongExport { has value: i64 = 0, negative: u8 = 0, ndigits: i64 = 0, "
             + "digits: ptr = ptr(), _reserved: u64 = 0; }"
         ),
         "PyLongLayout": (
             "obj PyLongLayout { has bits_per_digit: u8 = 0, digit_size: u8 = 0, "
             + "digits_order: i8 = 0, digit_endianness: i8 = 0; }"
         ),
         # A heap type's spec, for PyType_FromModuleAndSpec from C data.
         "PyType_Slot": "obj PyType_Slot { has slot: i32 = 0, pfunc: ptr = ptr(); }",
         "PyType_Spec": (
             "obj PyType_Spec { has name: ptr[u8] = ptr[u8](), basicsize: i32 = 0, "
             + "itemsize: i32 = 0, flags: u32 = 0, slots: ptr[PyType_Slot] = ptr[PyType_Slot](); }"
         ),
         "_PyTimeFraction": "obj _PyTimeFraction { has numer: i64 = 0, denom: i64 = 0; }",
         "_Py_clock_info_t": (
             "obj _Py_clock_info_t { has implementation: ptr[u8] = ptr[u8](), "
             + "monotonic: i32 = 0, adjustable: i32 = 0, resolution: f64 = 0.0; }"
         ),
         # <locale.h> struct lconv. glibc and macOS agree up to n_sign_posn;
         # the trailing int_* fields, which no port reads, follow macOS order.
         # The char fields are read as bytes; their signedness follows the
         # target's CHAR_MAX.
         "lconv": (
             "obj lconv { has decimal_point: ptr[u8], thousands_sep: ptr[u8], "
             + "grouping: ptr[u8], int_curr_symbol: ptr[u8], currency_symbol: ptr[u8], "
             + "mon_decimal_point: ptr[u8], mon_thousands_sep: ptr[u8], "
             + "mon_grouping: ptr[u8], positive_sign: ptr[u8], negative_sign: ptr[u8], "
             + "int_frac_digits: u8, frac_digits: u8, p_cs_precedes: u8, "
             + "p_sep_by_space: u8, n_cs_precedes: u8, n_sep_by_space: u8, "
             + "p_sign_posn: u8, n_sign_posn: u8, int_p_cs_precedes: u8, "
             + "int_n_cs_precedes: u8, int_p_sep_by_space: u8, int_n_sep_by_space: u8, "
             + "int_p_sign_posn: u8, int_n_sign_posn: u8; }"
         )
     },
     # C-layout records of interpreter internals a JacPython source walks.
     INTERNAL_STRUCTS: dict[str, str] = {
         "atexit_callback": (
             "obj atexit_callback { has func: Callable[[ptr], None], data: ptr, "
             + "next: ptr[atexit_callback]; }"
         ),
         # The union read through its `expat` member: 16 salt bytes, then the
         # legacy XML_SetHashSalt() salt.
         "_Py_HashSecret_t": (
             "obj _Py_HashSecret_t { has expat_hashsalt16_head: u64, "
             + "expat_hashsalt16_tail: u64, expat_hashsalt: i64; }"
         )
     },
     # Macros that name the address of a C object; each is a glob of that
     # address beside NULL, so Jac reads `value == Py_None` as C does.
     ADDRESS_MACROS: dict[str, str] = {
         "Py_None": "_Py_NoneStruct",
         "Py_NotImplemented": "_Py_NotImplementedStruct",
         "Py_Ellipsis": "_Py_EllipsisObject"
     },
     # Records a caller builds in Jac and lends for the call: a pointer
     # parameter to one is a borrow (`&T` when const, else `&mut T`).
     BORROWED: set[str] = {
         "PyMemberDef",
         "_PyTimeFraction",
         "_Py_clock_info_t",
         "PyLongExport"
     },
     # C library records whose layout differs between platforms. They are
     # declared by per-OS variant modules, imported from there, and borrowed.
     PLATFORM_RECORDS: dict[str, str] = {
         "timespec": "jaclang.runtime.python.modules.time_records",
         "timeval": "jaclang.runtime.python.modules.time_records",
         "tm": "jaclang.runtime.python.modules.time_records",
         "_Py_stat_struct": "jaclang.runtime.python.modules.stat_records"
     },
     SCALARS: dict[str, str] = {
         "int": "i32",
         "signed int": "i32",
         "unsigned int": "u32",
         "unsigned": "u32",
         "short": "i16",
         "unsigned short": "u16",
         "char": "i8",
         "signed char": "i8",
         "unsigned char": "u8",
         "long": "i64",
         "unsigned long": "u64",
         "long long": "i64",
         "unsigned long long": "u64",
         "size_t": "u64",
         "Py_ssize_t": "i64",
         "Py_hash_t": "i64",
         "Py_uhash_t": "u64",
         "int8_t": "i8",
         "uint8_t": "u8",
         "int16_t": "i16",
         "uint16_t": "u16",
         "int32_t": "i32",
         "uint32_t": "u32",
         "int64_t": "i64",
         "uint64_t": "u64",
         "intptr_t": "i64",
         "uintptr_t": "u64",
         "PyTime_t": "i64",
         "time_t": "i64",
         "_PyTime_round_t": "i32",
         # Enums of C int values.
         "PyGILState_STATE": "i32",
         "PySendResult": "i32",
         "wchar_t": "i32",
         "Py_UCS4": "u32",
         "Py_UCS1": "u8",
         "Py_UCS2": "u16",
         "uid_t": "u32",
         "gid_t": "u32",
         "double": "f64",
         "float": "f32",
         # 32-bit on every JacPython target (glibc and macOS).
         "wchar_t": "i32"
     },
     # Pointer typedefs passed through opaquely; a function pointer typedef
     # here can be passed NULL but not a Jac callback.
     POINTER_TYPEDEFS: dict[str, str] = {
         "PyCapsule_Destructor": "ptr",
         "PyThread_type_lock": "ptr",
         "vectorcallfunc": "ptr",
         "Py_tracefunc": "ptr",
         # A tp_traverse visitor, passed on as received.
         "visitproc": "ptr"
     },
     # A `const char *` parameter is a NUL-terminated C string (Jac `str`) unless
     # the function reads a sized payload; those take raw memory as `bytes`.
     PAYLOAD_PARAMETERS: dict[str, set[int]] = {
         "PyUnicode_DecodeUTF8": {0},
         "PyUnicode_Decode": {0},
         "PyUnicode_FromStringAndSize": {0},
         "PyUnicode_DecodeLatin1": {0},
         "PyUnicode_DecodeASCII": {0},
         "PyUnicodeWriter_WriteUTF8": {1},
         "PyLong_FromNativeBytes": {0},
         "PyFloat_Unpack2": {0},
         "PyFloat_Unpack4": {0},
         "PyFloat_Unpack8": {0}
     },
     # `char *` parameters of functions a Jac module now defines. A Jac C
     # definition cannot take `str` or `bytes`, and the program-wide C symbol
     # check holds every declaration to the definition, so these take the
     # address `ptr[u8]`.
     JAC_DEFINED_CHAR_PARAMETERS: dict[str, set[int]] = {
         "PyBytes_FromFormat": {0},
         "PyBytes_FromStringAndSize": {0},
         "PyByteArray_FromStringAndSize": {0},
         "PyDict_GetItemStringRef": {1},
         "PyDict_PopString": {1},
         "PyDict_SetItemString": {1},
         "PyContextVar_New": {0},
         "PyErr_Format": {1},
         "PyErr_FormatUnraisable": {0},
         "PyErr_NewException": {0},
         "PyErr_NewExceptionWithDoc": {0, 1},
         "PyErr_ResourceWarning": {2},
         "PyErr_SetString": {1},
         "PyErr_WarnEx": {1},
         "PyErr_WarnExplicit": {1, 2},
         "PyErr_WarnFormat": {2},
         "_PyErr_FormatFromCause": {1},
         "_PyTraceback_Add": {0, 1},
         "PyModule_New": {0},
         "PyUnicodeDecodeError_Create": {5},
         "PyUnicodeDecodeError_SetReason": {1},
         "PyUnicodeEncodeError_SetReason": {1},
         "PyUnicodeTranslateError_SetReason": {1},
         "PyArg_Parse": {1},
         "PyArg_ParseTuple": {1},
         "PyArg_ParseTupleAndKeywords": {2},
         "PyArg_UnpackTuple": {1},
         "Py_BuildValue": {0},
         "PyModule_Add": {1},
         "PyModule_AddIntConstant": {1},
         "PyModule_AddObjectRef": {1},
         "PyModule_AddStringConstant": {1, 2},
         "_PyArg_BadArgument": {0, 1, 2},
         "_PyArg_CheckPositional": {0},
         "_PyArg_NoKeywords": {0},
         "_PyArg_NoKwnames": {0},
         "_PyArg_NoPositional": {0},
         "PySys_Audit": {0, 1},
         "PySys_AuditTuple": {0},
         "_PySys_GetOptionalAttrString": {0}
     },
     # Pointer parameters that take memory the caller holds as a raw address
     # (a HACL* digest buffer, a Py_buffer, a path read after fork(), an
     # optional out-flag passed as NULL, a keyword-name array defined as C
     # data), not a Jac value; they take `ptr`.
     ADDRESS_PARAMETERS: dict[str, set[int]] = {
         "PyArg_ParseTupleAndKeywords": {3},
         "PyOS_string_to_double": {0, 1},
         "_Py_string_to_number_with_underscores": {0, 5},
         "_Py_strhex": {0},
         "_PyBytes_Find": {0, 2},
         "_PyBytes_ReverseFind": {0, 2},
         "_PyMem_Strdup": {0},
         "PyBytes_DecodeEscape": {0},
         "PyMember_GetOne": {0},
         "PyMember_SetOne": {0},
         "PyBytes_FromString": {0},
         "PyUnicode_DecodeFSDefault": {0},
         "PyUnicode_DecodeASCII": {0},
         "PyUnicode_DecodeCharmap": {0},
         "PyUnicodeDecodeError_Create": {0, 1},
         "PyUnicode_DecodeLatin1": {0},
         "PyUnicode_DecodeLocale": {0},
         "PyUnicode_DecodeLocaleAndSize": {0},
         "PyUnicode_DecodeUTF7Stateful": {0},
         "PyUnicode_DecodeUTF8Stateful": {0},
         "PyUnicode_DecodeUTF16Stateful": {0},
         "PyUnicode_DecodeUTF32Stateful": {0},
         "_PyUnicode_DecodeRawUnicodeEscapeStateful": {0},
         "_PyUnicode_DecodeUnicodeEscapeStateful": {0},
         "_Py_open_noraise": {0},
         "jacpy_opendir": {0},
         "_Py_set_inheritable_async_safe": {2}
     },
     # Pointer parameters that accept NULL. A `const char *` (an `errors` or
     # `encoding` name, where NULL selects the default) takes the C string
     # address `ptr[u8]` that clinic's nullable str converter produces; an
     # out-pointer takes `&mut T | None`, so None passes NULL.
     NULLABLE_PARAMETERS: dict[str, set[int]] = {
         "PyBytes_DecodeEscape": {2, 4},
         "PyOS_double_to_string": {4},
         "PyCodec_Decode": {1, 2},
         "PyCodec_Encode": {1, 2},
         "PyDict_Pop": {2},
         "PyDict_SetDefaultRef": {3},
         "PyErr_WarnExplicit": {4},
         "PyUnicode_AsWideCharString": {1},
         "PyUnicode_DecodeASCII": {2},
         "PyUnicode_DecodeCharmap": {3},
         "PyUnicode_DecodeLocale": {1},
         "PyUnicode_DecodeLatin1": {2},
         "PyUnicode_DecodeUTF7Stateful": {2, 3},
         "PyUnicode_DecodeUTF8Stateful": {2, 3},
         "PyUnicode_DecodeUTF16Stateful": {2, 4},
         "PyUnicode_DecodeUTF32Stateful": {2, 4},
         "_PyUnicode_AsASCIIString": {1},
         "_PyUnicode_AsLatin1String": {1},
         "_PyUnicode_AsUTF8String": {1},
         "_PyUnicode_DecodeRawUnicodeEscapeStateful": {2, 3},
         "_PyUnicode_DecodeUnicodeEscapeStateful": {2, 3},
         "_PyUnicode_EncodeCharmap": {2},
         "_PyUnicode_EncodeUTF7": {3},
         "_PyUnicode_EncodeUTF16": {1},
         "_PyUnicode_EncodeUTF32": {1},
         # atomic_flag_works: NULL where the platform has no SOCK_CLOEXEC.
         "_Py_set_inheritable": {2}
     },
     # `void *` out-parameters of converters whose C type the function fixes.
     TYPED_OUT_PARAMETERS: dict[str, dict[int, str]] = {
         "_PyLong_UnsignedShort_Converter": {1: "&mut u16"},
         "_PyLong_UnsignedInt_Converter": {1: "&mut u32"},
         "_PyLong_UInt16_Converter": {1: "&mut u16"},
         "_PyLong_UInt32_Converter": {1: "&mut u32"},
         "_PyLong_UInt8_Converter": {1: "&mut u8"},
         "_PyLong_UInt64_Converter": {1: "&mut u64"}
     },
     # `void *` parameters of a PyArg converter (`int conv(PyObject *, void *)`)
     # that receive the converted object.
     OBJECT_OUT_PARAMETERS: dict[str, set[int]] = {
         "PyUnicode_FSConverter": {1},
         "PyType_GetBaseByToken": {2}
     },
     # Pointer out-parameters the Jac side writes through `&mut`.
     OUT_POINTERS: dict[str, str] = {
         "PyObject **": "&mut ptr[PyObject]",
         "void **": "&mut ptr",
         "char **": "&mut ptr[u8]",
         "Py_ssize_t *": "&mut i64",
         "int *": "&mut i32",
         "double *": "&mut f64",
         "int64_t *": "&mut i64",
         "PyTime_t *": "&mut i64",
         "time_t *": "&mut i64",
         "long *": "&mut i64",
         "size_t *": "&mut u64",
         "uint64_t *": "&mut u64",
         "uint32_t *": "&mut u32",
         "uid_t *": "&mut u32",
         "gid_t *": "&mut u32"
     },
     KEYWORDS: set[str] = set(
         (
             "obj node edge walker root here visitor self super init has can def glob "
             + "impl sem test entry exit spawn visit disengage report ignore by to with "
             + "in is not and or if else elif for while return yield break continue try "
             + "except finally raise assert del import from as lambda async await class "
             + "enum include skip match case switch default flow wait priv pub protect "
             + "static override abs kw let type any str int float bool bytes list dict "
             + "set tuple ptr object len format hash iter next callable id"
         ).split()
     ),
     UNNAMED_TYPES: tuple[str, ...] = (
         "const",
         "struct",
         "unsigned",
         "signed",
         "long",
         "short"
     ),
     UNNAMED_NAMES: tuple[str, ...] = (
         "int",
         "long",
         "char",
         "short",
         "double",
         "float",
         "unsigned",
         "signed"
     ),
     API_FUNC: str = r"PyAPI_FUNC\(((?:[^()]|\([^()]*\))*)\)\s*([A-Za-z_]\w*)\s*\(((?:[^()]|\([^()]*\))*)\)",
     INTERNAL_EXTERN: str = r"^[ \t]*extern[ \t]+((?:const[ \t]+)?[A-Za-z_]\w*(?:[ \t]+\w+)*[ \t\*]*?[ \t]*\**?)\b([A-Za-z_]\w*)\s*\(((?:[^()]|\([^()]*\))*)\)\s*;",
     API_DATA: str = r"PyAPI_DATA\(([^()]*)\)\s*([A-Za-z_]\w*)\s*;",
     # A function the headers export with PyAPI_DATA (pycore_long.h's
     # `PyAPI_DATA(double) _PyLong_Frexp(PyLongObject *a, int64_t *e);`).
     API_DATA_FUNC: str = r"PyAPI_DATA\(([^()]*)\)\s*([A-Za-z_]\w*)\s*\(((?:[^()]|\([^()]*\))*)\)\s*;",
     INTERNAL_DATA: str = r"^[ \t]*extern[ \t]+((?:const[ \t]+)?[A-Za-z_]\w*[ \t\*]*?)[ \t]*\b([A-Za-z_]\w*)[ \t]*;",
     HELPER_DEF: str = r"^(?!static)((?:const )?\w+(?: \w+)*\s*\**)\s*(jacpy_\w+)\(([^)]*)\)\s*\{",
     # Typedef structs of the C helpers whose fields are all scalars.
     STRUCT_NAMES: dict[str, list[tuple[str, str]]] = {},
     # Names the JacPython sources call, as opposed to only mention.
     CALLED: set[str] = set(),
     # The jacpy_* helpers HELPER_PROTOTYPES declares.
     HELPER_FUNCTIONS: dict[str, tuple[str, list[tuple[str, str]]]] = {};

def normal(ctype: str) -> str {
    ctype = " ".join(ctype.replace("*", " * ").split());
    return ctype.replace("* *", "**").strip();
}

def parameters(raw: str) -> list[tuple[str, str]] {
    params: list[tuple[str, str]] = [];
    if not raw or raw == "void" {
        return params;
    }
    # Split at the top-level commas: a function-pointer parameter's own
    # parameter list stays one piece.
    pieces: list[str] = [];
    depth = 0;
    current = "";
    for character in raw {
        if character == "," and depth == 0 {
            pieces.append(current);
            current = "";
            continue;
        }
        if character == "(" {
            depth += 1;
        } elif character == ")" {
            depth -= 1;
        }
        current += character;
    }
    pieces.append(current);
    for piece in pieces {
        piece = piece.strip();
        split = re.match(r"^(.*?[\s\*])([A-Za-z_]\w*)$", piece);
        if split is not None
            and piece != "..."
            and split.group(1).strip()
            and split.group(1).strip() not in UNNAMED_TYPES
            and split.group(2) not in UNNAMED_NAMES
            and normal(piece) not in SCALARS {
            params.append((normal(split.group(1)), split.group(2)));
        } else {
            params.append((normal(piece), ""));
        }
    }
    return params;
}

# Header text without comments or line continuations.
def plain(text: str) -> str {
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S);
    return re.sub(r"//[^\n]*", " ", text).replace("\\\n", " ");
}

def declarations(
    texts: dict[str, str]
) -> dict[str, tuple[str, list[tuple[str, str]]]] {
    functions: dict[str, tuple[str, list[tuple[str, str]]]] = {};
    for path in sorted(texts) {
        text = plain(texts[path]);
        found = list(re.finditer(API_FUNC, text, re.S))
            + list(re.finditer(API_DATA_FUNC, text, re.S));
        # Internal headers also declare plain `extern` functions. jacpython.o
        # links into libpython itself, so they resolve like exported ones.
        if path.startswith("Include/internal/") {
            for hit in re.finditer(INTERNAL_EXTERN, text, re.M | re.S) {
                if '"' not in hit.group(0) {
                    found.append(hit);
                }
            }
        }
        for hit in found {
            name = hit.group(2);
            if name not in functions {
                functions[name] = (
                    normal(hit.group(1)),
                    parameters(" ".join(hit.group(3).split()))
                );
            }
        }
    }
    return functions;
}

# C types of the data symbols: PyAPI_DATA variables and, from the internal
# headers, plain `extern` variables (libpython resolves both for jacpython.o).
def data_declarations(texts: dict[str, str]) -> dict[str, str] {
    variables: dict[str, str] = {};
    for path in sorted(texts) {
        text = plain(texts[path]);
        found = list(re.finditer(API_DATA, text));
        if path.startswith("Include/internal/") {
            found += list(re.finditer(INTERNAL_DATA, text, re.M));
        }
        for hit in found {
            if hit.group(2) not in variables {
                variables[hit.group(2)] = normal(hit.group(1));
            }
        }
    }
    return variables;
}

# A data symbol's Jac type: an object pointer is read in place; a C object
# (a static type or singleton) is the opaque PyObject, used by address.
def data_type(ctype: str) -> str | None {
    base = ctype.replace("const ", "").replace(" const", "").strip();
    if base in ("PyObject *", "PyTypeObject *") {
        return "ptr[PyObject]";
    }
    if normal(base) == "char *" {
        return "ptr[u8]";
    }
    if base in OBJECT_LAYOUTS or base == "PyObject" {
        return "PyObject";
    }
    if base in INTERNAL_STRUCTS {
        return base;
    }
    # An opaque C object (_PyRuntime) is used by address.
    if base in OPAQUE {
        return base;
    }
    return SCALARS.get(base);
}

def jac_type(function: str, ctype: str, index: int | None) -> str | None {
    # A raw address, whatever the C type (a buffer position, a callback).
    if index is not None and index in ADDRESS_PARAMETERS.get(function, set()) {
        return "ptr";
    }
    # A vector of object arguments (`PyObject *const *args` of the vectorcall
    # API) is read, not written.
    if index is not None
        and re.fullmatch(r"PyObject\s*\*\s*const\s*\*", ctype.strip()) {
        return "ptr[ptr[PyObject]]";
    }
    base = ctype.replace("const ", "").replace(" const", "").strip();
    if normal(base) in ("void * *", "void **") and index is None {
        return "ptr[ptr]";
    }
    if index is not None and index in TYPED_OUT_PARAMETERS.get(function, {}) {
        return TYPED_OUT_PARAMETERS[function][index];
    }
    record = re.match(r"^(?:struct )?(\w+) \*$", base);
    if record
        and (record.group(1) in BORROWED or record.group(1) in PLATFORM_RECORDS) {
        if index is None {
            return None;
        }
        return ("&" if "const" in ctype else "&mut ") + record.group(1);
    }
    base = base.removeprefix("struct ");
    if base in STRUCT_NAMES or base in STRUCTS or base in INTERNAL_STRUCTS {
        return base;
    }
    if base == "void" {
        return "None";
    }
    if base in SCALARS {
        return SCALARS[base];
    }
    if base in POINTER_TYPEDEFS {
        return POINTER_TYPEDEFS[base];
    }
    if index is not None and base.endswith("*") {
        if index in OBJECT_OUT_PARAMETERS.get(function, set()) {
            return "&mut ptr[PyObject]";
        }
    }
    nullable = index is not None and index in NULLABLE_PARAMETERS.get(function, set());
    if base == "char *" {
        if index is None
            or nullable
            or index in JAC_DEFINED_CHAR_PARAMETERS.get(function, set()) {
            return "ptr[u8]";
        }
        if index in PAYLOAD_PARAMETERS.get(function, set()) or "const" not in ctype {
            return "bytes";
        }
        return "str";
    }
    if base == "void *" {
        return "ptr";
    }
    if base in ("PyObject * *", "PyObject **") and index is None {
        return "ptr[ptr[PyObject]]";
    }
    if ctype in OUT_POINTERS or base in OUT_POINTERS {
        if index is None {
            return None;
        }
        out = OUT_POINTERS.get(ctype, OUT_POINTERS.get(base));
        return f"{out} | None" if nullable else out;
    }
    hit = re.match(r"^(\w+(?: \w+)*) \*$", base);
    if hit {
        pointee = hit.group(1);
        if pointee in OBJECT_LAYOUTS {
            return "ptr[PyObject]";
        }
        if pointee in OPAQUE or pointee in STRUCTS or pointee in INTERNAL_STRUCTS {
            return f"ptr[{pointee}]";
        }
        if pointee in SCALARS {
            return f"ptr[{SCALARS[pointee]}]";
        }
    }
    return None;
}

# Exported jacpy_* definitions and scalar typedef structs of the C helpers.
def helpers -> tuple[
    dict[str, tuple[str, list[tuple[str, str]]]],
    dict[str, list[tuple[str, str]]]
] {
    functions: dict[str, tuple[str, list[tuple[str, str]]]] = {};
    structs: dict[str, list[tuple[str, str]]] = {};
    for text in ["\n".join(HELPER_PROTOTYPES)] {
        for hit in re.finditer(r"typedef struct \{([^{}]*)\}\s*(\w+);", text) {
            fields: list[tuple[str, str]] = [];
            scalar_only = True;
            for decl in hit.group(1).split(";") {
                decl = " ".join(decl.split());
                if not decl {
                    continue;
                }
                split = re.match(r"^(\w+(?: \w+)*?) (\w+(?:, \w+)*)$", decl);
                if not split or split.group(1) not in SCALARS {
                    scalar_only = False;
                    break;
                }
                fields += [
                    (split.group(1), name.strip()) for name in split.group(2).split(",")
                ];
            }
            if fields and scalar_only {
                structs[hit.group(2)] = fields;
            }
        }
        for hit in re.finditer(HELPER_DEF, text, re.M) {
            params: list[tuple[str, str]] = [];
            raw = " ".join(hit.group(3).split());
            if raw and raw != "void" {
                for piece in raw.split(",") {
                    split = re.match(r"^(.*?[\s\*])(\w+)$", piece.strip());
                    if split is not None {
                        params.append((normal(split.group(1)), split.group(2)));
                    }
                }
            }
            functions[hit.group(2)] = (normal(hit.group(1)), params);
        }
    }
    return (functions, structs);
}

def used_names(known: set[str]) -> set[str] {
    names: set[str] = set();
    # Functions a JacPython source defines under their C names (the interpreter
    # hooks of atexit) are provided, not called through a declaration, unless
    # a source imports one from cpython_api: code outside the object model
    # consumes the C API the way C includes a header, so it links against
    # whichever image defines the function.
    defined: set[str] = set();
    imported: set[str] = set();
    for tree in SOURCES {
        for path in tree.rglob("*.jac") {
            # A generator's formatting scratch directory (.gen_*) holds a
            # copy of the output while another run formats it.
            if path == OUTPUT
                or any(part.startswith(".") for part in path.relative_to(tree).parts) {
                continue;
            }
            # Comments, docstrings and string literals mention C names
            # without calling them.
            text = re.sub(r'"""(?:.|\n)*?"""', "", path.read_text());
            text = re.sub(r"(?m)^\s*#.*$", "", text);
            text = re.sub(r'"(?:\\.|[^"\\\n])*"', '""', text);
            names.update(re.findall(r"\b((?:_?Py|jacpy_)[A-Za-z0-9_]*)\b", text));
            for block in re.findall(
                r"import from jaclang\.runtime\.python\.cpython_api \{([^}]*)\}", text
            ) {
                imported.update(name.strip() for name in block.split(","));
            }
            CALLED.update(re.findall(r"\b((?:_?Py|jacpy_)[A-Za-z0-9_]*)\s*\(", text));
            # jac fmt joins the definitions of a C block onto the line that
            # closes the previous one (`}  def PyUnstable_AtExit(...) {`).
            defined.update(
                re.findall(
                    r"(?m)(?:^|\})\s*def(?::\w+)?\s+((?:_?Py|jacpy_)[A-Za-z0-9_]*)\b[^;{]*\{",
                    text
                )
            );
            # A source may declare a function itself when its C type has no
            # mapping here (a PyStatus returned by value, typed with the
            # layouts.jac record).
            defined.update(
                re.findall(
                    r"(?m)(?:^|(?<=[;}]))\s*def(?::\w+)?\s+((?:_?Py|jacpy_)[A-Za-z0-9_]*)\b[^;{]*;",
                    text
                )
            );
        }
    }
    # A jacpy_* helper is a Jac definition its callers still reach through a
    # declaration here, with a Jac str for each C string.
    provided = (defined - imported) - set(HELPER_FUNCTIONS);
    CALLED.difference_update(provided);
    return {
        name
        for name in names
        if name in known and name not in provided
    };
}

def render(
    functions: dict[str, tuple[str, list[tuple[str, str]]]],
    names: set[str],
    version: str,
    structs: dict[str, list[tuple[str, str]]],
    variables: dict[str, str],
    data_names: set[str],
    macros: set[str]
) -> str {
    lines = [
        '"""CPython C API declarations for native Jac modules.',
        "",
        f"Generated by scripts/jacpython/gen_capi.jac from CPython {version} headers;",
        "do not edit. Only the functions and data symbols the JacPython sources use",
        "are declared.",
        '"""',
        "import from c {"
    ];
    lines += [f"    obj {name};" for name in OPAQUE];
    lines += [f"    {STRUCTS[name]}" for name in sorted(STRUCTS)];
    lines += [f"    {INTERNAL_STRUCTS[name]}" for name in sorted(INTERNAL_STRUCTS)];
    for (name, fields) in sorted(structs.items()) {
        body = ", ".join(f"{field}: {SCALARS[kind]}" for (kind, field) in fields);
        lines.append(f"    obj {name} {{ has {body}; }}");
    }
    failures: list[str] = [];
    for name in sorted(names) {
        result: str = functions[name][0];
        params: list[tuple[str, str]] = functions[name][1];
        returned = jac_type(name, result, None);
        rendered: list[str] = [];
        mapped = True;
        for (index, (ctype, pname)) in enumerate(params) {
            # A C variadic function takes its extra arguments with C's default
            # promotions.
            if ctype == "..." {
                rendered.append("*args: any");
                break;
            }
            jtype = jac_type(name, ctype, index);
            if jtype is None {
                mapped = False;
                break;
            }
            pname = pname or f"arg{index}";
            # A parameter named like a type (pytime's `struct tm *tm`) would
            # shadow it.
            if pname in KEYWORDS or pname in PLATFORM_RECORDS or pname in STRUCTS {
                pname = pname + "_";
            }
            rendered.append(f"{pname}: {jtype}");
        }
        if returned is None or not mapped {
            if name in CALLED {
                failures.append(
                    f"{name}: {result} ({', '.join(c for (c, _) in params)})"
                );
            }
            continue;
        }
        tail = "" if returned == "None" else f" -> {returned}";
        lines.append(f"    def {name}({', '.join(rendered)}){tail};");
    }
    globs: list[str] = [];
    for name in sorted(data_names) {
        jtype = data_type(variables[name]);
        if jtype is None {
            failures.append(f"{name}: data {variables[name]}");
            continue;
        }
        globs.append(f"{name}: {jtype}");
    }
    if globs {
        lines.append(f"    glob {', '.join(globs)};");
    }
    lines.append("}");
    # Platform records a declaration borrows come from their variant modules.
    declared = "\n".join(lines);
    for module in sorted(set(PLATFORM_RECORDS.values()), reverse=True) {
        records = sorted(
            n
            for (n, m) in PLATFORM_RECORDS.items()
            if m == module and re.search(rf"&(?:mut )?{n}\b", declared)
        );
        if records {
            lines.insert(
                lines.index('"""', 1) + 1,
                f"import from {module} {{ {', '.join(records)} }}"
            );
        }
    }
    lines += ["", "glob NULL: Final[ptr[PyObject]] = ptr[PyObject]();"];
    for name in sorted(macros) {
        lines.append(
            f"glob {name}: Final[ptr[PyObject]] = addressof({ADDRESS_MACROS[name]});"
        );
    }
    if failures {
        sys.exit(
            "No Jac mapping for these used symbols (add a C helper or a mapping):\n  "
                + "\n  ".join(failures)
        );
    }
    return "\n".join(lines) + "\n";
}

with entry:__main__ {
    parser = argparse.ArgumentParser(description="Generate cpython_api.jac");
    parser.add_argument("--check", action="store_true");
    args = parser.parse_args();
    # Each header's declarations, as the C API table lists them.
    headers: dict[str, str] = {};
    for (path, _, declaration) in DECLARATIONS {
        headers[path] = headers.get(path, "") + declaration + "\n";
    }
    functions = declarations(headers);
    variables = data_declarations(headers);
    found = helpers();
    defined = found[0];
    HELPER_FUNCTIONS.update(defined);
    structs = found[1];
    STRUCT_NAMES.update(structs);
    functions.update(defined);
    used = used_names(set(functions) | set(variables) | set(ADDRESS_MACROS));
    names = {
        name
        for name in used
        if name in functions
    };
    macros = {
        name
        for name in used
        if name in ADDRESS_MACROS
    };
    data_names = {
        name
        for name in used
        if name in variables
    }
        | {ADDRESS_MACROS[name] for name in macros};
    unused = sorted(set(defined) - names);
    if unused {
        print(
            "C helpers no JacPython source uses:", ", ".join(unused), file=sys.stderr
        );
    }
    text = format_jac(
        render(
            functions, names, pin()["version"], structs, variables, data_names, macros
        ),
        OUTPUT
    );
    if not write_or_check(OUTPUT, text, args.check, "scripts/jacpython/gen_capi.jac") {
        sys.exit(1);
    }
}
