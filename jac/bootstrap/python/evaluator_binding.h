/* Argument storage ABI for the native Jac evaluator, CPython 3.14.6.
 * PSF licensed; see jaclang/runtime/python/LICENSE.cpython.
 */
#ifndef JAC_EVALUATOR_BINDING_H
#define JAC_EVALUATOR_BINDING_H
#include "evaluator_refs.h"
#include "evaluator_frames.h"
#include "internal/pycore_stackref.h"

typedef struct JacPyBindingStorage JacPyBindingStorage;
typedef JacPyBindingStorage *JacPyBindingRef;

/* These arrays belong to the active frame/caller. The binding resource owns
 * only the references not yet transferred or discarded. It never frees either
 * array, promotes a borrowed stackref, or clears the caller's const input.
 */
void jacpy_binding_close(JacPyBindingRef binding);
void jacpy_binding_disarm(JacPyBindingStorage *storage, JacPyBindingRef binding);
int64_t jacpy_binding_remaining(JacPyBindingRef binding);
int64_t jacpy_binding_position(JacPyBindingRef binding);
void jacpy_binding_move_next(JacPyBindingRef binding, int64_t local);
void jacpy_binding_discard_next(JacPyBindingRef binding);
JacPyObjectRef jacpy_binding_peek_next(JacPyBindingRef binding);
JacPyObjectRef jacpy_binding_pack(JacPyBindingRef binding, int64_t count);
void jacpy_binding_put_object(JacPyBindingRef binding, int64_t local, JacPyObjectRef value);
void jacpy_binding_copy_object(JacPyBindingRef binding, int64_t local, JacPyObjectRef value);
JacPyObjectRef jacpy_binding_local_object(JacPyBindingRef binding, int64_t local);
const void *jacpy_binding_locals(JacPyBindingRef binding);
JacPyObjectRef jacpy_binding_code(JacPyBindingRef binding);
JacPyObjectRef jacpy_binding_qualname(JacPyBindingRef binding);
JacPyObjectRef jacpy_binding_defaults(JacPyBindingRef binding);
JacPyObjectRef jacpy_binding_kwdefaults(JacPyBindingRef binding);
int32_t jacpy_binding_varargs(JacPyBindingRef binding);
int32_t jacpy_binding_varkeywords(JacPyBindingRef binding);
void jacpy_binding_suggestion_name(JacPyBindingRef binding, JacPyObjectRef names,
    int64_t local, int64_t output);
void jacpy_format_three_objects(PyThreadState *tstate, JacPyObjectRef exception,
    const char *format, JacPyObjectRef a, JacPyObjectRef b, JacPyObjectRef c);
typedef struct _PyInterpreterFrame JacPyFrameSpace;
JacPyFrameSpace *jacpy_frame_allocate(PyThreadState *tstate, JacPyObjectRef code);
int32_t jacpy_frame_space_is_null(JacPyFrameSpace *space);
JacPyFrameRef jacpy_frame_null(void);
JacPyFrameRef jacpy_frame_initialize(PyThreadState *tstate, JacPyFrameSpace *space,
    const void *arguments, JacPyFrameRef previous, JacPyStackRef function,
    JacPyObjectRef locals, JacPyObjectRef code);
void jacpy_binding_attach_frame(JacPyBindingRef binding, JacPyFrameRef frame);
typedef struct JacPyCallStorage JacPyCallStorage;
typedef JacPyCallStorage *JacPyCallArgsRef;
JacPyCallArgsRef jacpy_callargs_begin(JacPyCallStorage *storage);
void jacpy_callargs_close(JacPyCallArgsRef arguments);
void jacpy_callargs_use_small(JacPyCallArgsRef arguments, int64_t count);
int32_t jacpy_callargs_allocate(JacPyCallArgsRef arguments, int64_t count);
void jacpy_callargs_copy_next(JacPyCallArgsRef arguments, JacPyObjectRef value);
int64_t jacpy_callargs_pending(JacPyCallArgsRef arguments);
void jacpy_callargs_discard_next(JacPyCallArgsRef arguments);
void jacpy_callargs_release(JacPyCallStorage *storage, JacPyCallArgsRef arguments);
JacPyObjectRef jacpy_object_array_item(PyObject *const *values, int64_t index);
JacPyFrameRef jacpy_frame_previous_null(PyThreadState *tstate);
int32_t jacpy_frame_is_null(JacPyFrameRef frame);
JacPyFrameRef jacpy_callargs_push_frame(PyThreadState *tstate, JacPyCallArgsRef arguments,
    JacPyFrameRef previous, JacPyStackRef function, JacPyObjectRef locals,
    int64_t positional, JacPyObjectRef keywords);
void jacpy_eval_vector_stat(void);
JacPyObjectRef jacpy_eval_owned_frame(PyThreadState *tstate, JacPyFrameRef frame, int32_t throwflag);
typedef struct JacPyLocalTransferSlot JacPyLocalTransferSlot;
JacPyFrameRef jacpy_frame_push_ex(PyThreadState *tstate, _PyStackRef function,
    PyObject *locals, Py_ssize_t positional, PyObject *values, PyObject *keywords,
    JacPyFrameRef previous);
JacPyObjectRef jacpy_locals_transfer(JacPyLocalTransferSlot *slot);
int64_t jacpy_call_dict_size(JacPyObjectRef dictionary);
int32_t jacpy_callargs_unpack(JacPyCallArgsRef arguments, PyThreadState *tstate,
    JacPyObjectRef values, int64_t positional, JacPyObjectRef keywords);
void jacpy_callargs_convert_next(JacPyCallArgsRef arguments);
int64_t jacpy_callargs_filled(JacPyCallArgsRef arguments);
int64_t jacpy_callargs_capacity(JacPyCallArgsRef arguments);
JacPyObjectRef jacpy_callargs_keywords(JacPyCallArgsRef arguments);
typedef struct JacPyLegacyStorage JacPyLegacyStorage;
typedef JacPyLegacyStorage *JacPyLegacyArgsRef;
JacPyLegacyArgsRef jacpy_legacy_arguments_begin(JacPyLegacyStorage *storage,
    PyObject *const *arguments, PyObject *const *keywords);
void jacpy_legacy_arguments_close(JacPyLegacyArgsRef arguments);
int32_t jacpy_legacy_arguments_allocate(JacPyLegacyArgsRef arguments, int64_t count);
void jacpy_legacy_arguments_copy(JacPyLegacyArgsRef arguments, int64_t source, int64_t destination);
void jacpy_legacy_keyword_copy(JacPyLegacyArgsRef arguments, int64_t source, int64_t destination);
PyObject *const *jacpy_legacy_arguments_values(JacPyLegacyArgsRef arguments);
PyObject *const *jacpy_object_array_null(void);
JacPyObjectRef jacpy_tuple_from_array(PyObject *const *values, int64_t count);
void jacpy_tuple_initialize_item(JacPyObjectRef tuple, int64_t index, JacPyObjectRef value);
JacPyObjectRef jacpy_function_from_code(JacPyObjectRef code, JacPyObjectRef globals,
    JacPyObjectRef builtins, JacPyObjectRef defaults, JacPyObjectRef keyword_defaults,
    JacPyObjectRef closure);
void jacpy_eval_legacy_stat(void);
typedef struct JacPyScratchStorage JacPyScratchStorage;
typedef JacPyScratchStorage *JacPyScratchArrayRef;
void jacpy_scratch_close(JacPyScratchArrayRef array);
int32_t jacpy_scratch_allocate(JacPyScratchArrayRef array, int64_t count);
void jacpy_scratch_use_caller(JacPyScratchArrayRef array);
void jacpy_scratch_copy(JacPyScratchArrayRef array, int64_t index);
void jacpy_scratch_publish(JacPyScratchStorage *storage, JacPyScratchArrayRef array);
#endif
