/* Object-runtime operations for native Jac evaluator algorithms.
 * CPython 3.14.6, PSF licensed; see jaclang/runtime/python/LICENSE.cpython.
 */
#ifndef JAC_EVALUATOR_OBJECTS_H
#define JAC_EVALUATOR_OBJECTS_H
#include "evaluator_refs.h"

typedef void *JacPyLookupRef;
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
JacPyObjectRef jacpy_code_local_name(JacPyObjectRef code, int32_t index);
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
#endif
