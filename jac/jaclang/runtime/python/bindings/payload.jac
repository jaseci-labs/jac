"""Native state owned by a Python object through an opaque ABI payload slot."""
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.module { jacpy_binding_visit }
import from jaclang.runtime.python.bindings.type {
    jacpy_binding_typeof,
    jacpy_binding_dict_visit,
    jacpy_binding_dict_clear,
    jacpy_binding_free
}

import from c {
    # get returns an owned native reference; set retains its borrowed argument.
    def jacpy_binding_native_get(object: u64, definition: u64) -> NativeState;  def jacpy_binding_native_set(
        object: u64, definition: u64, state: NativeState
    ) -> i64;  def jacpy_binding_native_clear(object: u64, definition: u64);  def jacpy_binding_native_present(
        object: u64, definition: u64
    ) -> i64;  def jacpy_binding_untrack(object: u64);  def jacpy_binding_clear_weakrefs(
        object: u64
    );
}

def traverse_payload(
    instance: u64, definition: u64, visitor: u64, context: u64
) -> i32 {
    result = jacpy_binding_visit(jacpy_binding_typeof(instance), visitor, context);
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

def clear_payload(instance: u64, definition: u64) -> i32 {
    if jacpy_binding_native_present(instance, definition) != 0 {
        state = jacpy_binding_native_get(instance, definition);
        state.clear();
    }
    jacpy_binding_dict_clear(instance, definition);
    return i32(0);
}

def dispose_payload(instance: u64, definition: u64) {
    jacpy_binding_untrack(instance);
    clear_payload(instance, definition);
    jacpy_binding_clear_weakrefs(instance);
    jacpy_binding_native_clear(instance, definition);
    jacpy_binding_free(instance);
}

import from c {
    def jacpy_binding_dealloc_guard(
        object: u64, callback: Callable[[u64], None], body: Callable[[u64], None]
    );
}
