"""Python operator dispatch and callable accessors, executed in native Jac.

Derived from CPython 3.14.6; see ../LICENSE.cpython.
"""
import from jaclang.runtime.python.capi {
    jacpy_crypto_compare,
    jacpy_retain,
    jacpy_release,
    jacpy_none,
    jacpy_int,
    object_error,
    jacpy_tuple_new,
    jacpy_tuple_size,
    jacpy_tuple_item,
    jacpy_tuple_set_owned,
    jacpy_list_size,
    jacpy_list_item,
    jacpy_add,
    jacpy_sub,
    jacpy_mul,
    jacpy_matmul,
    jacpy_floordiv,
    jacpy_truediv,
    jacpy_mod,
    jacpy_lshift,
    jacpy_rshift,
    jacpy_and_,
    jacpy_xor,
    jacpy_or_,
    jacpy_iadd,
    jacpy_isub,
    jacpy_imul,
    jacpy_imatmul,
    jacpy_ifloordiv,
    jacpy_itruediv,
    jacpy_imod,
    jacpy_ilshift,
    jacpy_irshift,
    jacpy_iand,
    jacpy_ixor,
    jacpy_ior,
    jacpy_concat,
    jacpy_iconcat,
    jacpy_getitem,
    jacpy_neg,
    jacpy_pos,
    jacpy_abs,
    jacpy_invert,
    jacpy_index,
    jacpy_power,
    jacpy_truth,
    jacpy_boolean,
    jacpy_is_none,
    jacpy_compare,
    jacpy_contains,
    jacpy_sequence_index,
    jacpy_sequence_count,
    jacpy_length_hint,
    jacpy_setitem,
    jacpy_delitem,
    jacpy_getattr,
    jacpy_call,
    jacpy_tuple_slice,
    jacpy_is_unicode,
    jacpy_text,
    jacpy_repr,
    jacpy_repr_enter,
    jacpy_repr_leave,
    jacpy_unicode_split,
    jacpy_unicode_join,
    jacpy_dict_size,
    jacpy_dict_entry,
    jacpy_import_attr,
    jacpy_utf8,
    jacpy_integer_value,
    jacpy_error_pending,
    boundary_failure,
    required,
    text_object,
    text_value,
    repr_value,
    pair
}


# Preparing dotted paths once avoids reparsing attributes on every invocation.
def:pub jacpy_operator_prepare(kind: i64, args: u64) -> u64 {
    result: u64 = 0;
    try {
        count = jacpy_tuple_size(args);
        if kind == 0 {
            return jacpy_retain(args);
        }
        if kind == 2 {
            name = required(jacpy_tuple_item(args, 0));
            try {
                if jacpy_is_unicode(name) == 0 {
                    object_error("TypeError", "method name must be a string");
                    return 0;
                }
            } finally {
                jacpy_release(name);
            }
            return jacpy_retain(args);
        }
        result = required(jacpy_tuple_new(count));
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
        return 0;
    }
}

def get_attribute_path(target: u64, path: u64) -> u64 {
    current = jacpy_retain(target);
    try {
        for i in range(int(jacpy_list_size(path))) {
            name = required(jacpy_list_item(path, i64(i)));
            following: u64 = 0;
            try {
                following = required(jacpy_getattr(current, name));
            } finally {
                jacpy_release(name);
            }
            jacpy_release(current);
            current = following;
        }
        return jacpy_retain(current);
    } finally {
        jacpy_release(current);
    }
}

def:pub jacpy_operator_apply(kind: i64, target: u64, args: u64, kwargs: u64) -> u64 {
    result: u64 = 0;
    try {
        count = jacpy_tuple_size(args);
        if kind == 2 {
            name = required(jacpy_tuple_item(args, 0));
            callable: u64 = 0;
            try {
                callable = required(jacpy_getattr(target, name));
            } finally {
                jacpy_release(name);
            }
            try {
                positional = required(jacpy_tuple_slice(args, 1, count));
                try {
                    return jacpy_call(callable, positional, kwargs);
                } finally {
                    jacpy_release(positional);
                }
            } finally {
                jacpy_release(callable);
            }
        }
        if count > 1 {
            result = required(jacpy_tuple_new(count));
        }
        for i in range(int(count)) {
            key = required(jacpy_tuple_item(args, i64(i)));
            value: u64 = 0;
            try {
                value = required(jacpy_getitem(target, key))
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
        return 0;
    }
}

def getter_arguments(kind: i64, args: u64) -> u64 {
    if kind != 1 {
        return jacpy_retain(args);
    }
    result = required(jacpy_tuple_new(jacpy_tuple_size(args)));
    try {
        separator = text_object(".");
        try {
            for i in range(int(jacpy_tuple_size(args))) {
                path = required(jacpy_tuple_item(args, i64(i)));
                value: u64 = 0;
                try {
                    value = required(jacpy_unicode_join(separator, path));
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

def:pub jacpy_operator_repr(kind: i64, self: u64, args: u64, kwargs: u64) -> u64 {
    entered = jacpy_repr_enter(self);
    if entered < 0 {
        return 0;
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
            for i in range(1 if kind == 2 else 0, int(jacpy_tuple_size(originals))) {
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
                        position = jacpy_integer_value(pos);
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
        return 0;
    } finally {
        if entered == 0 {
            jacpy_repr_leave(self);
        }
    }
}

def:pub jacpy_operator_reduce(kind: i64, type: u64, args: u64, kwargs: u64) -> u64 {
    try {
        originals = getter_arguments(kind, args);
        try {
            if kind != 2 or jacpy_dict_size(kwargs) == 0 {
                return pair(type, originals);
            }
            partial = required(jacpy_import_attr("functools", "partial"));
            constructor: u64 = 0;
            try {
                name = required(jacpy_tuple_item(originals, 0));
                try {
                    parameters = pair(type, name);
                    try {
                        constructor = required(jacpy_call(partial, parameters, kwargs));
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
                    jacpy_tuple_slice(originals, 1, jacpy_tuple_size(originals))
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
        return 0;
    }
}

def:pub jacpy_operator_add(a: u64, b: u64) -> u64 {
    return jacpy_add(a, b);
}

def:pub jacpy_operator_sub(a: u64, b: u64) -> u64 {
    return jacpy_sub(a, b);
}

def:pub jacpy_operator_mul(a: u64, b: u64) -> u64 {
    return jacpy_mul(a, b);
}

def:pub jacpy_operator_matmul(a: u64, b: u64) -> u64 {
    return jacpy_matmul(a, b);
}

def:pub jacpy_operator_floordiv(a: u64, b: u64) -> u64 {
    return jacpy_floordiv(a, b);
}

def:pub jacpy_operator_truediv(a: u64, b: u64) -> u64 {
    return jacpy_truediv(a, b);
}

def:pub jacpy_operator_mod(a: u64, b: u64) -> u64 {
    return jacpy_mod(a, b);
}

def:pub jacpy_operator_lshift(a: u64, b: u64) -> u64 {
    return jacpy_lshift(a, b);
}

def:pub jacpy_operator_rshift(a: u64, b: u64) -> u64 {
    return jacpy_rshift(a, b);
}

def:pub jacpy_operator_and_(a: u64, b: u64) -> u64 {
    return jacpy_and_(a, b);
}

def:pub jacpy_operator_xor(a: u64, b: u64) -> u64 {
    return jacpy_xor(a, b);
}

def:pub jacpy_operator_or_(a: u64, b: u64) -> u64 {
    return jacpy_or_(a, b);
}

def:pub jacpy_operator_iadd(a: u64, b: u64) -> u64 {
    return jacpy_iadd(a, b);
}

def:pub jacpy_operator_isub(a: u64, b: u64) -> u64 {
    return jacpy_isub(a, b);
}

def:pub jacpy_operator_imul(a: u64, b: u64) -> u64 {
    return jacpy_imul(a, b);
}

def:pub jacpy_operator_imatmul(a: u64, b: u64) -> u64 {
    return jacpy_imatmul(a, b);
}

def:pub jacpy_operator_ifloordiv(a: u64, b: u64) -> u64 {
    return jacpy_ifloordiv(a, b);
}

def:pub jacpy_operator_itruediv(a: u64, b: u64) -> u64 {
    return jacpy_itruediv(a, b);
}

def:pub jacpy_operator_imod(a: u64, b: u64) -> u64 {
    return jacpy_imod(a, b);
}

def:pub jacpy_operator_ilshift(a: u64, b: u64) -> u64 {
    return jacpy_ilshift(a, b);
}

def:pub jacpy_operator_irshift(a: u64, b: u64) -> u64 {
    return jacpy_irshift(a, b);
}

def:pub jacpy_operator_iand(a: u64, b: u64) -> u64 {
    return jacpy_iand(a, b);
}

def:pub jacpy_operator_ixor(a: u64, b: u64) -> u64 {
    return jacpy_ixor(a, b);
}

def:pub jacpy_operator_ior(a: u64, b: u64) -> u64 {
    return jacpy_ior(a, b);
}

def:pub jacpy_operator_concat(a: u64, b: u64) -> u64 {
    return jacpy_concat(a, b);
}

def:pub jacpy_operator_iconcat(a: u64, b: u64) -> u64 {
    return jacpy_iconcat(a, b);
}

def:pub jacpy_operator_getitem(a: u64, b: u64) -> u64 {
    return jacpy_getitem(a, b);
}

def:pub jacpy_operator_neg(a: u64) -> u64 {
    return jacpy_neg(a);
}

def:pub jacpy_operator_pos(a: u64) -> u64 {
    return jacpy_pos(a);
}

def:pub jacpy_operator_abs(a: u64) -> u64 {
    return jacpy_abs(a);
}

def:pub jacpy_operator_invert(a: u64) -> u64 {
    return jacpy_invert(a);
}

def:pub jacpy_operator_index(a: u64) -> u64 {
    return jacpy_index(a);
}

def bool_result(value: i64) -> u64 {
    if value < 0 {
        return 0;
    }
    return jacpy_boolean(value);
}

def integer_result(value: i64) -> u64 {
    if value == -1 and jacpy_error_pending() != 0 {
        return 0;
    }
    return jacpy_int(value);
}

def:pub jacpy_operator_truth(a: u64) -> u64 {
    return bool_result(jacpy_truth(a));
}

def:pub jacpy_operator_not_(a: u64) -> u64 {
    value = jacpy_truth(a);
    if value < 0 {
        return 0;
    }
    return jacpy_boolean(1 - value);
}

def:pub jacpy_operator_is_(a: u64, b: u64) -> u64 {
    return jacpy_boolean(i64(a == b));
}

def:pub jacpy_operator_is_not(a: u64, b: u64) -> u64 {
    return jacpy_boolean(i64(a != b));
}

def:pub jacpy_operator_is_none(a: u64) -> u64 {
    return jacpy_boolean(jacpy_is_none(a));
}

def:pub jacpy_operator_is_not_none(a: u64) -> u64 {
    return jacpy_boolean(1 - jacpy_is_none(a));
}

def:pub jacpy_operator_pow(a: u64, b: u64) -> u64 {
    return jacpy_power(a, b, 0);
}

def:pub jacpy_operator_ipow(a: u64, b: u64) -> u64 {
    return jacpy_power(a, b, 1);
}

def:pub jacpy_operator_compare(a: u64, b: u64, operation: i64) -> u64 {
    return jacpy_compare(a, b, operation);
}

def:pub jacpy_operator_contains(a: u64, b: u64) -> u64 {
    return bool_result(jacpy_contains(a, b));
}

def:pub jacpy_operator_indexOf(a: u64, b: u64) -> u64 {
    return integer_result(jacpy_sequence_index(a, b));
}

def:pub jacpy_operator_countOf(a: u64, b: u64) -> u64 {
    return integer_result(jacpy_sequence_count(a, b));
}

def:pub jacpy_operator_length_hint(a: u64, fallback: i64) -> u64 {
    return integer_result(jacpy_length_hint(a, fallback));
}

def:pub jacpy_operator_setitem(a: u64, b: u64, value: u64) -> u64 {
    if jacpy_setitem(a, b, value) < 0 {
        return 0;
    }
    return jacpy_none();
}

def:pub jacpy_operator_delitem(a: u64, b: u64) -> u64 {
    if jacpy_delitem(a, b) < 0 {
        return 0;
    }
    return jacpy_none();
}

def:pub jacpy_operator_call(args: u64, kwargs: u64) -> u64 {
    try {
        callable = required(jacpy_tuple_item(args, 0));
        try {
            tail = required(jacpy_tuple_slice(args, 1, jacpy_tuple_size(args)));
            try {
                return jacpy_call(callable, tail, kwargs);
            } finally {
                jacpy_release(tail);
            }
        } finally {
            jacpy_release(callable);
        }
    } except boundary_failure {
        return 0;
    }
}

# Reuse the cryptographic constant-time primitive already supplied by OpenSSL.
# Comparisons of unequal sizes still read the second operand in full.
def:pub jacpy_operator_digest(a: u64, b: u64, a_size: i64, b_size: i64) -> u64 {
    left = a if a_size == b_size else b;
    difference = jacpy_crypto_compare(left, b, b_size);
    return jacpy_boolean(i64((difference == 0) and (a_size == b_size)));
}
