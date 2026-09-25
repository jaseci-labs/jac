import from jaclang.runtime.python.cpython_api { PyObject }

"""Ownership and Python cycle-visitation protocol for native binding state."""
obj NativeState {
    def traverse_refs(visitor: ptr, context: ptr) -> i32 abst;
    def clear abst;
}
