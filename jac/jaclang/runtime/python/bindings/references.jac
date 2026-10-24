obj ReferenceState(NativeState) {
    has references: list[ptr[PyObject]];

    def clear;
    def traverse_refs(visitor: ptr, context: ptr) -> i32;
    def drop;
}

def owned_tuple(values: list[ptr[PyObject]]) -> ptr[PyObject];

def call_method(
    target: ptr[PyObject], name: str, arguments: list[ptr[PyObject]]
) -> ptr[PyObject];

impl ReferenceState.clear {
    i = 0;
    while i < len(self.references) {
        value = self.references[i];
        self.references[i] = NULL;
        jacpy_release(value);
        i += 1;
    }
}

impl ReferenceState.traverse_refs(visitor: ptr, context: ptr) -> i32 {
    for value in self.references {
        result = visit_reference(value, visitor, context);
        if result != 0 {
            return result;
        }
    }
    return i32(0);
}

impl ReferenceState.drop {
    self.clear();
}

impl owned_tuple(values: list[ptr[PyObject]]) -> ptr[PyObject] {
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

impl call_method(
    target: ptr[PyObject], name: str, arguments: list[ptr[PyObject]]
) -> ptr[PyObject] {
    packed = owned_tuple(arguments);
    if not packed {
        return NULL;
    }
    method = jacpy_object_getattr_text(target, name);
    if not method {
        jacpy_release(packed);
        return NULL;
    }
    result = PyObject_Call(method, packed, NULL);
    jacpy_release(method);
    jacpy_release(packed);
    return result;
}
