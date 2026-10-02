"""Shared ownership and cycle-collector visibility for Python reference fields."""

import from jaclang.runtime.python.cpython_api {
    jacpy_release,
    jacpy_tuple_set_owned,
    NULL,
    PyObject,
    PyObject_Call,
    PyObject_GetAttrString,
    PyTuple_New
}
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.module { visit_reference }

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
            result = visit_reference(value, visitor, context);
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

# target.name(*arguments), as PyObject_CallMethod does with a fixed format.
# The arguments are owned references, consumed on every path.
def call_method(
    target: ptr[PyObject], name: str, arguments: list[ptr[PyObject]]
) -> ptr[PyObject] {
    packed = owned_tuple(arguments);
    if not packed {
        return NULL;
    }
    method = PyObject_GetAttrString(target, name);
    if not method {
        jacpy_release(packed);
        return NULL;
    }
    result = PyObject_Call(method, packed, NULL);
    jacpy_release(method);
    jacpy_release(packed);
    return result;
}
