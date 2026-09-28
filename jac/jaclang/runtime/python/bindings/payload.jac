"""Native state owned by a Python object through an opaque ABI payload slot."""

import from jaclang.runtime.python.cpython_api { PyObject, Py_TYPE }
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.module { jacpy_binding_visit }
import from jaclang.runtime.python.bindings.type {
    jacpy_binding_dict_visit,
    jacpy_binding_dict_clear,
    jacpy_binding_free
}

import from c {
    # get returns an owned native reference; set retains its borrowed argument.
    def jacpy_binding_native_get(
        object: ptr[PyObject], definition: ptr
    ) -> NativeState;  def jacpy_binding_native_set(
        object: ptr[PyObject], definition: ptr, state: NativeState
    ) -> i64;  def jacpy_binding_native_clear(object: ptr[PyObject], definition: ptr);  def jacpy_binding_native_present(
        object: ptr[PyObject], definition: ptr
    ) -> i64;  def jacpy_binding_untrack(object: ptr[PyObject]);  def jacpy_binding_clear_weakrefs(
        object: ptr[PyObject]
    );
}

def traverse_payload(
    instance: ptr[PyObject], definition: ptr, visitor: ptr, context: ptr
) -> i32 {
    result = jacpy_binding_visit(Py_TYPE(instance), visitor, context);
    if result != 0 {
        return result;
    }
    result = jacpy_binding_dict_visit(instance, definition, visitor, context);
    if result != 0 {
        return result;
    }
    if jacpy_binding_native_present(instance, definition) != 0 {
        state = jacpy_binding_native_get(instance, definition);
        return state.traverse_refs(visitor, context);
    }
    return i32(0);
}

def clear_payload(instance: ptr[PyObject], definition: ptr) -> i32 {
    if jacpy_binding_native_present(instance, definition) != 0 {
        state = jacpy_binding_native_get(instance, definition);
        state.clear();
    }
    jacpy_binding_dict_clear(instance, definition);
    return i32(0);
}

def dispose_payload(instance: ptr[PyObject], definition: ptr) {
    jacpy_binding_untrack(instance);
    clear_payload(instance, definition);
    jacpy_binding_clear_weakrefs(instance);
    jacpy_binding_native_clear(instance, definition);
    jacpy_binding_free(instance);
}

import from c {
    def jacpy_binding_dealloc_guard(
        object: ptr[PyObject],
        callback: Callable[[ptr[PyObject]], None],
        body: Callable[[ptr[PyObject]], None]
    );
}
