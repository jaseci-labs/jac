"""Shared ownership and cycle-collector visibility for Python reference fields."""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyObject,
    PyTuple_New,
    jacpy_release,
    jacpy_tuple_set_owned
}
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.module { jacpy_binding_visit }

obj ReferenceState(NativeState) {
    has references: list[ptr[PyObject]];

    def clear {
        previous = self.references;
        self.references = [NULL for _ in previous];
        for value in previous {
            jacpy_release(value);
        }
    }

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
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
def owned_tuple(values: list[ptr[PyObject]]) -> ptr[PyObject] {
    held = ReferenceState(references=values);
    for value in values {
        if value == 0 {
            return NULL;
        }
    }
    result = PyTuple_New(i64(len(values)));
    if result == 0 {
        return NULL;
    }
    for i in range(len(values)) {
        value = held.references[i];
        held.references[i] = NULL;
        if jacpy_tuple_set_owned(result, i64(i), value) < 0 {
            jacpy_release(result);
            return NULL;
        }
    }
    return result;
}
