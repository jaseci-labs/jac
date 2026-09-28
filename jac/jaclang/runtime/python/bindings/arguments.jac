"""Argument ownership and signature binding shared by native Python adapters."""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyDict_Items,
    PyList_GetItemRef,
    PyLong_AsSsize_t,
    PyNumber_Index,
    PyObject,
    PyTuple_Size,
    PyUnicode_ReadChar,
    Py_NewRef,
    jacpy_error_pending,
    jacpy_is_unicode,
    jacpy_list_size,
    jacpy_release,
    jacpy_tuple_item,
    jacpy_unicode_size
}
import from jaclang.runtime.python.capi {
    boundary_failure,
    required,
    object_error,
    text_value
}

obj BoundArguments {
    has values: list[ptr[PyObject]],
        context: ptr[PyObject] = NULL,
        keywords: ptr[PyObject] = NULL;

    def drop {
        for value in self.values {
            jacpy_release(value);
        }
        jacpy_release(self.keywords);
    }
}

def invalid(message: str) -> bool {
    object_error("TypeError", message);
    return False;
}

def index_value(value: ptr[PyObject]) -> (i64 | None) {
    index = PyNumber_Index(value);
    if index == 0 {
        return None;
    }
    try {
        result = PyLong_AsSsize_t(index);
        if result == -1 and jacpy_error_pending() != 0 {
            return None;
        }
        return result;
    } finally {
        jacpy_release(index);
    }
}

obj CallSignature {
    has name: str,
        names: list[str],
        required_count: int,
        positional_count: int,
        positional_only: int = 0;

    def bind(
        result: BoundArguments, args: ptr[PyObject], kwargs: ptr[PyObject]
    ) -> bool {
        count = int(PyTuple_Size(args));
        if count < 0 {
            return False;
        }
        if count > self.positional_count {
            return invalid(
                f"{self.name}() takes at most {self.positional_count} positional arguments ({count} given)"
            );
        }
        for i in range(count) {
            result.values[i] = required(jacpy_tuple_item(args, i64(i)));
        }
        if kwargs != 0 {
            items = required(PyDict_Items(kwargs));
            try {
                for i in range(int(jacpy_list_size(items))) {
                    item = required(PyList_GetItemRef(items, i64(i)));
                    key: ptr[PyObject] = NULL;
                    try {
                        key = required(jacpy_tuple_item(item, 0));
                        if jacpy_is_unicode(key) == 0 {
                            return invalid("keywords must be strings");
                        }
                        name = text_value(key);
                        index = -1;
                        for j in range(self.positional_only, len(self.names)) {
                            if self.names[j] == name {
                                index = j;
                                break;
                            }
                        }
                        if index < 0 {
                            return invalid(
                                f"{self.name}() got an unexpected keyword argument '{name}'"
                            );
                        }
                        if result.values[index] != 0 {
                            return invalid(
                                f"argument for {self.name}() given by name ('{name}') and position ({index
                                    + 1})"
                            );
                        }
                        result.values[index] = required(jacpy_tuple_item(item, 1));
                    } finally {
                        jacpy_release(key);
                        jacpy_release(item);
                    }
                }
            } finally {
                jacpy_release(items);
            }
        }
        for i in range(self.required_count) {
            if result.values[i] == 0 {
                return invalid(
                    f"{self.name}() missing required argument '{self.names[i]}' (pos {i
                        + 1})"
                );
            }
        }
        return True;
    }
}

def invoke(
    signature: CallSignature,
    args: ptr[PyObject],
    kwargs: ptr[PyObject],
    implementation: Callable[[BoundArguments], ptr[PyObject]],
    context: ptr[PyObject] = 0,
    forward_keywords: bool = False
) -> ptr[PyObject] {
    # The call frame lives outside the exception region: every exit releases
    # all converted arguments, including a failure in a nested conversion.
    bound = BoundArguments([NULL for _ in signature.names], context);
    if forward_keywords and kwargs != 0 {
        bound.keywords = Py_NewRef(kwargs);
    }
    try {
        if not signature.bind(bound, args, NULL if forward_keywords else kwargs) {
            return NULL;
        }
        return implementation(bound);
    } except boundary_failure {
        return NULL;
    }
}

def invoke_one(
    value: ptr[PyObject], implementation: Callable[[ptr[PyObject]], ptr[PyObject]]
) -> ptr[PyObject] {
    try {
        return implementation(value);
    } except boundary_failure {
        return NULL;
    }
}

def character_value(value: ptr[PyObject], context: str) -> (i64 | None) {
    if jacpy_is_unicode(value) == 0 or jacpy_unicode_size(value) != 1 {
        object_error("TypeError", f"{context}() argument must be a unicode character");
        return None;
    }
    return PyUnicode_ReadChar(value, 0);
}
