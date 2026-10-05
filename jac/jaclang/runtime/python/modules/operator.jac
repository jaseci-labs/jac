"""Python operator dispatch and callable accessors, executed in native Jac.

Derived from CPython 3.14.6; see ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyBool_FromLong,
    PyImport_ImportModuleAttrString,
    PyList_GetItemRef,
    PyLong_AsLongLong,
    PyLong_FromLongLong,
    PyNumber_Absolute,
    PyNumber_Add,
    PyNumber_And,
    PyNumber_FloorDivide,
    PyNumber_InPlaceAdd,
    PyNumber_InPlaceAnd,
    PyNumber_InPlaceFloorDivide,
    PyNumber_InPlaceLshift,
    PyNumber_InPlaceMatrixMultiply,
    PyNumber_InPlaceMultiply,
    PyNumber_InPlaceOr,
    PyNumber_InPlaceRemainder,
    PyNumber_InPlaceRshift,
    PyNumber_InPlaceSubtract,
    PyNumber_InPlaceTrueDivide,
    PyNumber_InPlaceXor,
    PyNumber_Index,
    PyNumber_Invert,
    PyNumber_Lshift,
    PyNumber_MatrixMultiply,
    PyNumber_Multiply,
    PyNumber_Negative,
    PyNumber_Or,
    PyNumber_Positive,
    PyNumber_Remainder,
    PyNumber_Rshift,
    PyNumber_Subtract,
    PyNumber_TrueDivide,
    PyNumber_Xor,
    PyObject,
    PyObject_Call,
    PyObject_DelItem,
    PyObject_GetAttr,
    PyObject_GetItem,
    PyObject_IsTrue,
    PyObject_LengthHint,
    PyObject_Repr,
    PyObject_RichCompare,
    PyObject_SetItem,
    PySequence_Concat,
    PySequence_Contains,
    PySequence_Count,
    PySequence_InPlaceConcat,
    PySequence_Index,
    PyTuple_GetSlice,
    PyTuple_New,
    PyTuple_Size,
    PyUnicode_Join,
    Py_NewRef,
    Py_ReprEnter,
    Py_ReprLeave,
    jacpy_crypto_compare,
    jacpy_dict_entry,
    jacpy_dict_size,
    jacpy_error_pending,
    jacpy_is_none,
    jacpy_is_unicode,
    jacpy_list_size,
    jacpy_none,
    jacpy_power,
    jacpy_release,
    jacpy_text,
    jacpy_tuple_item,
    jacpy_tuple_set_owned,
    jacpy_unicode_split,
    jacpy_utf8
}
import from jaclang.runtime.python.capi {
    object_error,
    boundary_failure,
    required,
    text_object,
    text_value,
    repr_value,
    pair
}

# Preparing dotted paths once avoids reparsing attributes on every invocation.
def:pub jacpy_operator_prepare(kind: i64, args: ptr[PyObject]) -> ptr[PyObject] {
    result: ptr[PyObject] = NULL;
    try {
        count = PyTuple_Size(args);
        if kind == 0 {
            return Py_NewRef(args);
        }
        if kind == 2 {
            name = required(jacpy_tuple_item(args, 0));
            try {
                if jacpy_is_unicode(name) == 0 {
                    object_error("TypeError", "method name must be a string");
                    return NULL;
                }
            } finally {
                jacpy_release(name);
            }
            return Py_NewRef(args);
        }
        result = required(PyTuple_New(count));
        separator = text_object(".");
        try {
            for i in range(int(count)) {
                name = required(jacpy_tuple_item(args, i64(i)));
                try {
                    if jacpy_is_unicode(name) == 0 {
                        object_error("TypeError", "attribute name must be a string");
                        raise boundary_failure();
                    }
                    path = required(jacpy_unicode_split(name, separator));
                    jacpy_tuple_set_owned(result, i64(i), path);
                } finally {
                    jacpy_release(name);
                }
            }
        } finally {
            jacpy_release(separator);
        }
        return result;
    } except boundary_failure {
        if result != 0 {
            jacpy_release(result);
        }
        return NULL;
    }
}

def get_attribute_path(target: ptr[PyObject], path: ptr[PyObject]) -> ptr[PyObject] {
    current = Py_NewRef(target);
    try {
        for i in range(int(jacpy_list_size(path))) {
            name = required(PyList_GetItemRef(path, i64(i)));
            following: ptr[PyObject] = NULL;
            try {
                following = required(PyObject_GetAttr(current, name));
            } finally {
                jacpy_release(name);
            }
            jacpy_release(current);
            current = following;
        }
        return Py_NewRef(current);
    } finally {
        jacpy_release(current);
    }
}

def:pub jacpy_operator_apply(
    kind: i64, target: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    result: ptr[PyObject] = NULL;
    try {
        count = PyTuple_Size(args);
        if kind == 2 {
            name = required(jacpy_tuple_item(args, 0));
            callable: ptr[PyObject] = NULL;
            try {
                callable = required(PyObject_GetAttr(target, name));
            } finally {
                jacpy_release(name);
            }
            try {
                positional = required(PyTuple_GetSlice(args, 1, count));
                try {
                    return PyObject_Call(callable, positional, kwargs);
                } finally {
                    jacpy_release(positional);
                }
            } finally {
                jacpy_release(callable);
            }
        }
        if count > 1 {
            result = required(PyTuple_New(count));
        }
        for i in range(int(count)) {
            key = required(jacpy_tuple_item(args, i64(i)));
            value: ptr[PyObject] = NULL;
            try {
                value = required(PyObject_GetItem(target, key))
                    if kind == 0
                    else get_attribute_path(target, key);
            } finally {
                jacpy_release(key);
            }
            if count == 1 {
                return value;
            }
            jacpy_tuple_set_owned(result, i64(i), value);
        }
        return result;
    } except boundary_failure {
        if result != 0 {
            jacpy_release(result);
        }
        return NULL;
    }
}

def getter_arguments(kind: i64, args: ptr[PyObject]) -> ptr[PyObject] {
    if kind != 1 {
        return Py_NewRef(args);
    }
    result = required(PyTuple_New(PyTuple_Size(args)));
    try {
        separator = text_object(".");
        try {
            for i in range(int(PyTuple_Size(args))) {
                path = required(jacpy_tuple_item(args, i64(i)));
                value: ptr[PyObject] = NULL;
                try {
                    value = required(PyUnicode_Join(separator, path));
                } finally {
                    jacpy_release(path);
                }
                jacpy_tuple_set_owned(result, i64(i), value);
            }
        } finally {
            jacpy_release(separator);
        }
        return result;
    } except boundary_failure {
        jacpy_release(result);
        raise;
    }
}

def:pub jacpy_operator_repr(
    kind: i64, self: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    entered = Py_ReprEnter(self);
    if entered < 0 {
        return NULL;
    }
    name = "operator.itemgetter"
        if kind == 0
        else ("operator.attrgetter" if kind == 1 else "operator.methodcaller");
    try {
        if entered != 0 {
            return text_object(name + "(...)");
        }
        originals = getter_arguments(kind, args);
        try {
            parts: list[str] = [];
            for i in range(1 if kind == 2 else 0, int(PyTuple_Size(originals))) {
                item = required(jacpy_tuple_item(originals, i64(i)));
                try {
                    parts.append(repr_value(item));
                } finally {
                    jacpy_release(item);
                }
            }
            if kind == 2 {
                expected = jacpy_dict_size(kwargs);
                position: i64 = 0;
                seen: i64 = 0;
                while kwargs != 0 {
                    record = jacpy_dict_entry(kwargs, position);
                    if record == 0 {
                        if jacpy_error_pending() != 0 {
                            raise boundary_failure();
                        }
                        break;
                    }
                    try {
                        pos = required(jacpy_tuple_item(record, 0));
                        position = PyLong_AsLongLong(pos);
                        jacpy_release(pos);
                        key = required(jacpy_tuple_item(record, 1));
                        try {
                            value = required(jacpy_tuple_item(record, 2));
                            try {
                                parts.append(text_value(key) + "=" + repr_value(value));
                            } finally {
                                jacpy_release(value);
                            }
                        } finally {
                            jacpy_release(key);
                        }
                        seen += 1;
                        if seen > expected {
                            break;
                        }
                    } finally {
                        jacpy_release(record);
                    }
                }
                if seen != expected {
                    object_error(
                        "RuntimeError", "keywords dict changed size during iteration"
                    );
                    raise boundary_failure();
                }
            }
            prefix = "";
            if kind == 2 {
                method_name = required(jacpy_tuple_item(originals, 0));
                try {
                    prefix = repr_value(method_name);
                } finally {
                    jacpy_release(method_name);
                }
                if len(parts) > 0 {
                    prefix += ", ";
                }
            }
            return text_object(name + "(" + prefix + ", ".join(parts) + ")");
        } finally {
            jacpy_release(originals);
        }
    } except boundary_failure {
        return NULL;
    } finally {
        if entered == 0 {
            Py_ReprLeave(self);
        }
    }
}

def:pub jacpy_operator_reduce(
    kind: i64, type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        originals = getter_arguments(kind, args);
        try {
            if kind != 2 or jacpy_dict_size(kwargs) == 0 {
                return pair(type, originals);
            }
            partial = required(PyImport_ImportModuleAttrString("functools", "partial"));
            constructor: ptr[PyObject] = NULL;
            try {
                name = required(jacpy_tuple_item(originals, 0));
                try {
                    parameters = pair(type, name);
                    try {
                        constructor = required(
                            PyObject_Call(partial, parameters, kwargs)
                        );
                    } finally {
                        jacpy_release(parameters);
                    }
                } finally {
                    jacpy_release(name);
                }
            } finally {
                jacpy_release(partial);
            }
            try {
                tail = required(
                    PyTuple_GetSlice(originals, 1, PyTuple_Size(originals))
                );
                try {
                    return pair(constructor, tail);
                } finally {
                    jacpy_release(tail);
                }
            } finally {
                jacpy_release(constructor);
            }
        } finally {
            jacpy_release(originals);
        }
    } except boundary_failure {
        return NULL;
    }
}

def:pub jacpy_operator_add(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_Add(a, b);
}

def:pub jacpy_operator_sub(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_Subtract(a, b);
}

def:pub jacpy_operator_mul(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_Multiply(a, b);
}

def:pub jacpy_operator_matmul(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_MatrixMultiply(a, b);
}

def:pub jacpy_operator_floordiv(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_FloorDivide(a, b);
}

def:pub jacpy_operator_truediv(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_TrueDivide(a, b);
}

def:pub jacpy_operator_mod(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_Remainder(a, b);
}

def:pub jacpy_operator_lshift(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_Lshift(a, b);
}

def:pub jacpy_operator_rshift(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_Rshift(a, b);
}

def:pub jacpy_operator_and_(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_And(a, b);
}

def:pub jacpy_operator_xor(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_Xor(a, b);
}

def:pub jacpy_operator_or_(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_Or(a, b);
}

def:pub jacpy_operator_iadd(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_InPlaceAdd(a, b);
}

def:pub jacpy_operator_isub(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_InPlaceSubtract(a, b);
}

def:pub jacpy_operator_imul(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_InPlaceMultiply(a, b);
}

def:pub jacpy_operator_imatmul(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_InPlaceMatrixMultiply(a, b);
}

def:pub jacpy_operator_ifloordiv(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_InPlaceFloorDivide(a, b);
}

def:pub jacpy_operator_itruediv(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_InPlaceTrueDivide(a, b);
}

def:pub jacpy_operator_imod(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_InPlaceRemainder(a, b);
}

def:pub jacpy_operator_ilshift(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_InPlaceLshift(a, b);
}

def:pub jacpy_operator_irshift(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_InPlaceRshift(a, b);
}

def:pub jacpy_operator_iand(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_InPlaceAnd(a, b);
}

def:pub jacpy_operator_ixor(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_InPlaceXor(a, b);
}

def:pub jacpy_operator_ior(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_InPlaceOr(a, b);
}

def:pub jacpy_operator_concat(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return PySequence_Concat(a, b);
}

def:pub jacpy_operator_iconcat(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return PySequence_InPlaceConcat(a, b);
}

def:pub jacpy_operator_getitem(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return PyObject_GetItem(a, b);
}

def:pub jacpy_operator_neg(a: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_Negative(a);
}

def:pub jacpy_operator_pos(a: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_Positive(a);
}

def:pub jacpy_operator_abs(a: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_Absolute(a);
}

def:pub jacpy_operator_invert(a: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_Invert(a);
}

def:pub jacpy_operator_index(a: ptr[PyObject]) -> ptr[PyObject] {
    return PyNumber_Index(a);
}

def bool_result(value: i64) -> ptr[PyObject] {
    if value < 0 {
        return NULL;
    }
    return PyBool_FromLong(value);
}

def integer_result(value: i64) -> ptr[PyObject] {
    if value == -1 and jacpy_error_pending() != 0 {
        return NULL;
    }
    return PyLong_FromLongLong(value);
}

def:pub jacpy_operator_truth(a: ptr[PyObject]) -> ptr[PyObject] {
    return bool_result(PyObject_IsTrue(a));
}

def:pub jacpy_operator_not_(a: ptr[PyObject]) -> ptr[PyObject] {
    value = PyObject_IsTrue(a);
    if value < 0 {
        return NULL;
    }
    return PyBool_FromLong(1 - value);
}

def:pub jacpy_operator_is_(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return PyBool_FromLong(i64(a == b));
}

def:pub jacpy_operator_is_not(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return PyBool_FromLong(i64(a != b));
}

def:pub jacpy_operator_is_none(a: ptr[PyObject]) -> ptr[PyObject] {
    return PyBool_FromLong(jacpy_is_none(a));
}

def:pub jacpy_operator_is_not_none(a: ptr[PyObject]) -> ptr[PyObject] {
    return PyBool_FromLong(1 - jacpy_is_none(a));
}

def:pub jacpy_operator_pow(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_power(a, b, 0);
}

def:pub jacpy_operator_ipow(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_power(a, b, 1);
}

def:pub jacpy_operator_compare(
    a: ptr[PyObject], b: ptr[PyObject], operation: i64
) -> ptr[PyObject] {
    return PyObject_RichCompare(a, b, i32(operation));
}

def:pub jacpy_operator_contains(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return bool_result(PySequence_Contains(a, b));
}

def:pub jacpy_operator_indexOf(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return integer_result(PySequence_Index(a, b));
}

def:pub jacpy_operator_countOf(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    return integer_result(PySequence_Count(a, b));
}

def:pub jacpy_operator_length_hint(a: ptr[PyObject], fallback: i64) -> ptr[PyObject] {
    return integer_result(PyObject_LengthHint(a, fallback));
}

def:pub jacpy_operator_setitem(
    a: ptr[PyObject], b: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    if PyObject_SetItem(a, b, value) < 0 {
        return NULL;
    }
    return jacpy_none();
}

def:pub jacpy_operator_delitem(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    if PyObject_DelItem(a, b) < 0 {
        return NULL;
    }
    return jacpy_none();
}

def:pub jacpy_operator_call(
    args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        callable = required(jacpy_tuple_item(args, 0));
        try {
            tail = required(PyTuple_GetSlice(args, 1, PyTuple_Size(args)));
            try {
                return PyObject_Call(callable, tail, kwargs);
            } finally {
                jacpy_release(tail);
            }
        } finally {
            jacpy_release(callable);
        }
    } except boundary_failure {
        return NULL;
    }
}

# Reuse the cryptographic constant-time primitive already supplied by OpenSSL.
# Comparisons of unequal sizes still read the second operand in full.
def:pub jacpy_operator_digest(
    a: ptr, b: ptr, a_size: i64, b_size: i64
) -> ptr[PyObject] {
    left = a if a_size == b_size else b;
    difference = jacpy_crypto_compare(left, b, b_size);
    return PyBool_FromLong(i64((difference == 0) and (a_size == b_size)));
}
