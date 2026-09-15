/* Object-runtime operations for native Jac evaluator algorithms.
 * CPython 3.14.6, PSF licensed; see jaclang/runtime/python/LICENSE.cpython.
 */
#ifndef JAC_EVALUATOR_OBJECTS_H
#define JAC_EVALUATOR_OBJECTS_H
#include "evaluator_refs.h"

typedef void *JacPyLookupRef;
typedef struct { int64_t offset; } JacPyExceptionCursor;
int64_t jacpy_exception_table_size(JacPyObjectRef code);
int32_t jacpy_exception_table_byte(JacPyObjectRef code, int64_t offset);
int jacpy_get_exception_handler(PyCodeObject *code, int index, int *level, int *handler, int *lasti);
void jacpy_lookup_close(JacPyLookupRef result);
int32_t jacpy_lookup_state(JacPyLookupRef result);
JacPyObjectRef jacpy_lookup_take(JacPyLookupRef result);
JacPyLookupRef jacpy_mapping_lookup(JacPyObjectRef mapping, JacPyObjectRef key);
JacPyLookupRef jacpy_dict_lookup(JacPyObjectRef dictionary, JacPyObjectRef key);
JacPyLookupRef jacpy_attribute_lookup(JacPyObjectRef value, JacPyObjectRef name);
JacPyLookupRef jacpy_module_origin_lookup(JacPyObjectRef specification);
JacPyLookupRef jacpy_sys_lookup(const char *name);

int32_t jacpy_object_has_iter(JacPyObjectRef value);
JacPyObjectRef jacpy_exception_type(PyThreadState *tstate, int32_t kind);
void jacpy_format_function_type_error(PyThreadState *tstate, const char *format,
                                    JacPyObjectRef function, JacPyObjectRef operand);
void jacpy_format_objects_error(PyThreadState *tstate, JacPyObjectRef exception,
                               const char *format, JacPyObjectRef first, JacPyObjectRef second);
void jacpy_format_cstring_error(PyThreadState *tstate, JacPyObjectRef exception,
                               const char *format, const char *value);
int32_t jacpy_cstring_is_null(const char *value);
int32_t jacpy_object_is(JacPyObjectRef left, JacPyObjectRef right);
int32_t jacpy_name_error_has_name(JacPyObjectRef exception);
JacPyObjectRef jacpy_eval_identifier(PyThreadState *tstate, int32_t identifier);
JacPyObjectRef jacpy_code_local_name(JacPyObjectRef code, int64_t index);
int32_t jacpy_code_first_free(JacPyObjectRef code);
const char *jacpy_eval_error_format(int32_t kind);
int32_t jacpy_type_has_await(JacPyObjectRef type);
void jacpy_format_type_error(PyThreadState *tstate, const char *format, JacPyObjectRef type);
int32_t jacpy_method_check(JacPyObjectRef value);
int32_t jacpy_function_check(JacPyObjectRef value);
int32_t jacpy_cfunction_check(JacPyObjectRef value);
JacPyObjectRef jacpy_method_function(JacPyObjectRef method);
JacPyObjectRef jacpy_function_name(JacPyObjectRef function);
const char *jacpy_cfunction_name(JacPyObjectRef function);
const char *jacpy_object_type_name(JacPyObjectRef value);
const char *jacpy_function_description(int32_t callable);
JacPyObjectRef jacpy_object_type(JacPyObjectRef value);
JacPyObjectRef jacpy_type_lookup(JacPyObjectRef type, JacPyObjectRef name);
int32_t jacpy_object_has_descr_get(JacPyObjectRef value);
void jacpy_eval_fatal(const char *message);
JacPyObjectRef jacpy_none(PyThreadState *tstate);
void jacpy_set_string_error(PyThreadState *tstate, JacPyObjectRef exception, const char *message);
JacPyObjectRef jacpy_vectorcall_five(JacPyObjectRef function, JacPyObjectRef a,
    JacPyObjectRef b, JacPyObjectRef c, JacPyObjectRef d, JacPyObjectRef e);
JacPyObjectRef jacpy_unicode_format_four(const char *format, JacPyObjectRef a,
    JacPyObjectRef b, JacPyObjectRef c, JacPyObjectRef d);
int32_t jacpy_unicode_check(JacPyObjectRef value);
int32_t jacpy_anyset_check(JacPyObjectRef value);
int32_t jacpy_module_check(JacPyObjectRef value);
int64_t jacpy_code_argcount(JacPyObjectRef code);
int64_t jacpy_code_kwonlyargcount(JacPyObjectRef code);
int64_t jacpy_code_posonlyargcount(JacPyObjectRef code);
int64_t jacpy_list_size(JacPyObjectRef list);
JacPyObjectRef jacpy_list_item(JacPyObjectRef list, int64_t index);
void jacpy_list_initialize_item(JacPyObjectRef list, int64_t index, JacPyObjectRef item);
int32_t jacpy_list_delete_slice(JacPyObjectRef list, int64_t start, int64_t end);
const char *jacpy_argument_text(int32_t kind);
void jacpy_format_missing_error(PyThreadState *tstate, JacPyObjectRef qualname,
    int64_t count, const char *kind, const char *plural, JacPyObjectRef names);
JacPyObjectRef jacpy_unicode_format_sizes(const char *format, int64_t first, int64_t second);
JacPyObjectRef jacpy_unicode_format_kwonly(const char *given_plural, int64_t count, const char *plural);
void jacpy_format_positional_error(PyThreadState *tstate, JacPyObjectRef qualname,
    JacPyObjectRef signature, const char *plural, int64_t given,
    JacPyObjectRef keyword_signature, const char *verb);
int32_t jacpy_stack_array_is_null(const void *array, int64_t index);
int32_t jacpy_stack_array_has_object(const void *array, int64_t index);
typedef struct JacPyMatchStorage JacPyMatchStorage;
typedef JacPyMatchStorage *JacPyMatchRootsRef;
JacPyMatchRootsRef jacpy_match_roots_begin(JacPyMatchStorage *storage, PyThreadState *tstate,
    JacPyObjectRef mapping);
void jacpy_match_roots_close(JacPyMatchRootsRef roots);
int32_t jacpy_match_get_method(JacPyMatchRootsRef roots);
int32_t jacpy_match_has_self(JacPyMatchRootsRef roots);
JacPyObjectRef jacpy_match_call_self(JacPyMatchRootsRef roots, JacPyObjectRef key, JacPyObjectRef missing);
JacPyObjectRef jacpy_match_call_bound(JacPyMatchRootsRef roots, JacPyObjectRef key, JacPyObjectRef missing);
JacPyObjectRef jacpy_match_dummy(void);
int32_t jacpy_type_check(JacPyObjectRef value);
int32_t jacpy_tuple_exact(JacPyObjectRef value);
int32_t jacpy_unicode_exact(JacPyObjectRef value);
int32_t jacpy_type_match_self(JacPyObjectRef type);
JacPyObjectRef jacpy_match_args_name(PyThreadState *tstate);
void jacpy_match_duplicate(PyThreadState *tstate, JacPyObjectRef type, JacPyObjectRef name);
void jacpy_match_args_type_error(PyThreadState *tstate, JacPyObjectRef type, JacPyObjectRef match_args);
void jacpy_match_arity_error(PyThreadState *tstate, JacPyObjectRef type, int64_t allowed,
    const char *plural, int64_t given);
int32_t jacpy_exception_group_check(JacPyObjectRef value);
JacPyObjectRef jacpy_tuple_single(JacPyObjectRef value);
JacPyObjectRef jacpy_traceback_from_frame(JacPyObjectRef frame);
JacPyObjectRef jacpy_exception_group_split(JacPyObjectRef exception, JacPyObjectRef type);
void jacpy_exception_split_type_error(JacPyObjectRef exception, JacPyObjectRef pair);
void jacpy_exception_split_size_error(JacPyObjectRef exception, int64_t size);
void jacpy_exception_group_leak_on_traceback_error(JacPyObjectRef exception);
#endif
