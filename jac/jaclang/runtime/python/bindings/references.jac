"""Shared ownership and cycle-collector visibility for Python reference fields."""
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.module { jacpy_binding_visit }
import from jaclang.runtime.python.capi { jacpy_release }

obj ReferenceState(NativeState) {
    has references: list[u64];

    def clear {
        previous = self.references;
        self.references = [u64(0) for _ in previous];
        for value in previous {
            jacpy_release(value);
        }
    }

    def traverse_refs(visitor: u64, context: u64) -> i32 {
        for value in self.references {
            result = jacpy_binding_visit(value, visitor, context);
            if result != 0 {
                return result;
            }
        }
        return i32(0);
    }

    def drop {
        self.clear();
    }
}
