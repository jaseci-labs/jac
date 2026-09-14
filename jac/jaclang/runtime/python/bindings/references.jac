"""Shared ownership and cycle-collector visibility for Python reference fields."""
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.module { jacpy_binding_visit }
import from jaclang.runtime.python.capi {
    jacpy_release,
    jacpy_tuple_new,
    jacpy_tuple_set_owned
}

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

# Consume all supplied owned references, including when tuple allocation fails.
def owned_tuple(values: list[u64]) -> u64 {
    held = ReferenceState(references=values);
    for value in values {
        if value == 0 {
            return 0;
        }
    }
    result = jacpy_tuple_new(i64(len(values)));
    if result == 0 {
        return 0;
    }
    for i in range(len(values)) {
        value = held.references[i];
        held.references[i] = 0;
        if jacpy_tuple_set_owned(result, i64(i), value) < 0 {
            jacpy_release(result);
            return 0;
        }
    }
    return result;
}
