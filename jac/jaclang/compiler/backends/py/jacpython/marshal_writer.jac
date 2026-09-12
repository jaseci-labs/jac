"""Native serialization of compiler results for CPython 3.14's marshal reader.

Only compiler constants and code objects cross this boundary. The emitted
bytecode belongs to the compiled Python program. No compiler implementation
is serialized or executed by the receiving Python runtime.
"""
import from jaclang.runtime.python.objects {
    PyObj,
    PyNoneType,
    PyEllipsis,
    PyBool,
    PyInt,
    PyFloat,
    PyComplex,
    PyStr,
    PyBytes,
    PyTuple,
    PySet,
    PySlice,
    PyCode
}

obj marshal_output {
    has data: list[int] = [],
        references: dict[int, int] = {},
        error: str = "";
}

def write_word(out: marshal_output, value: int, width: int) {
    for shift in range(width) {
        out.data.append((value >> (shift * 8)) & 255);
    }
}

def write_bytes(out: marshal_output, value: list[int]) {
    out.data.append(115);
    write_word(out, len(value), 4);
    out.data.extend(value);
}

def write_text(out: marshal_output, value: str) {
    encoded = value.encode("utf-8", "surrogatepass");
    out.data.append(117);
    write_word(out, len(encoded), 4);
    for item in encoded {
        out.data.append(item);
    }
}

def write_names(out: marshal_output, values: list[str]) {
    out.data.append(40);
    write_word(out, len(values), 4);
    for value in values {
        write_text(out, value);
    }
}

def write_long(out: marshal_output, value: int) {
    # Avoid negating INT64_MIN; Jac's native integer payload is signed i64.
    negative = value < 0;
    remaining = -(value + 1) if negative else value;
    carry = 1 if negative else 0;
    digits: list[int] = [];
    while remaining > 0 or carry > 0 {
        digit = (remaining & 32767) + carry;
        digits.append(digit & 32767);
        carry = digit >> 15;
        remaining = remaining >> 15;
    }
    write_word(out, -len(digits) if negative else len(digits), 4);
    for digit in digits {
        write_word(out, digit, 2);
    }
}

def write_code(out: marshal_output, code: PyCode) {
    write_word(out, code.argcount, 4);
    write_word(out, code.posonlyargcount, 4);
    write_word(out, code.kwonlyargcount, 4);
    write_word(out, code.stacksize, 4);
    write_word(out, code.flags, 4);
    write_bytes(out, code.co_code);
    out.data.append(40);
    write_word(out, len(code.consts), 4);
    for value in code.consts {
        write_value(out, value);
    }
    write_names(out, code.names);

    # CPython merges argument cells into existing local slots, then appends
    # nonlocal cells and free variables in their compiler-assigned order.
    names: list[str] = [];
    kinds: list[int] = [];
    slots: dict[str, int] = {};
    for name in code.varnames {
        slots[name] = len(names);
        names.append(name[6:] if name.startswith(".comp.") else name);
        kinds.append(32 | (16 if not (code.flags & 1) else 0));
    }
    for name in code.cellvars {
        if name in slots {
            index = slots[name];
            kinds[index] = kinds[index] | 64;
        } else {
            names.append(name);
            kinds.append(64);
        }
    }
    for name in code.freevars {
        names.append(name);
        kinds.append(128);
    }
    write_names(out, names);
    write_bytes(out, kinds);
    write_text(out, code.filename);
    write_text(out, code.name);
    write_text(out, code.qualname);
    write_word(out, code.firstlineno, 4);
    write_bytes(out, code.linetable);
    write_bytes(out, code.exceptiontable);
}

def write_value(out: marshal_output, value: PyObj) {
    if out.error {
        return;
    }
    # The reader never registers singleton tags in its reference table.
    if isinstance(value, PyNoneType) {
        out.data.append(78);
        return;
    }
    if isinstance(value, PyEllipsis) {
        out.data.append(46);
        return;
    }
    if isinstance(value, PyBool) {
        out.data.append(84 if value.val else 70);
        return;
    }
    identity = id(value);
    if identity in out.references {
        out.data.append(114);
        write_word(out, out.references[identity], 4);
        return;
    }
    out.references[identity] = len(out.references);
    # FLAG_REF reserves the object before its children are decoded.
    if isinstance(value, PyInt) {
        out.data.append(108 | 128);
        write_long(out, value.val);
    } elif isinstance(value, PyFloat) {
        out.data.append(103 | 128);
        write_word(out, __float_bits(value.val), 8);
    } elif isinstance(value, PyComplex) {
        out.data.append(121 | 128);
        write_word(out, __float_bits(value.real), 8);
        write_word(out, __float_bits(value.imag), 8);
    } elif isinstance(value, PyStr) {
        start = len(out.data);
        write_text(out, value.val);
        out.data[start] = out.data[start] | 128;
    } elif isinstance(value, PyBytes) {
        start = len(out.data);
        write_bytes(out, value.val);
        out.data[start] = out.data[start] | 128;
    } elif isinstance(value, PyTuple) {
        out.data.append(40 | 128);
        write_word(out, len(value.items), 4);
        for item in value.items {
            write_value(out, item);
        }
    } elif isinstance(value, PySet) and value.frozen {
        out.data.append(62 | 128);
        write_word(out, len(value.items), 4);
        for item in value.items.values() {
            write_value(out, item);
        }
    } elif isinstance(value, PySlice) {
        out.data.append(58 | 128);
        write_value(out, value.start);
        write_value(out, value.stop);
        write_value(out, value.step);
    } elif isinstance(value, PyCode) {
        out.data.append(99 | 128);
        write_code(out, value);
    } else {
        out.error = "Unsupported compiler constant: " + value.t;
    }
}

def marshal_constant(value: PyObj) -> marshal_output {
    result = marshal_output();
    write_value(result, value);
    if result.error {
        result.data = [];
    }
    return result;
}
