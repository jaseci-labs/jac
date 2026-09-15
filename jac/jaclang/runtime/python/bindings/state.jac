"""Ownership and Python cycle-visitation protocol for native binding state."""
obj NativeState {
    def traverse_refs(visitor: u64, context: u64) -> i32 abst;
    def clear abst;
}
