"""Compiler constants and code objects become retained CPython values."""
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
import from jaclang.runtime.python.compiler_integer { PyBigInt }
import from jaclang.runtime.python.constant_keys { constant_key }
import from jaclang.runtime.python.opcode_meta {
    CO_OPTIMIZED,
    CO_FAST_HIDDEN,
    CO_FAST_LOCAL,
    CO_FAST_CELL,
    CO_FAST_FREE
}
import from jaclang.runtime.python.capi {
    checked,
    required,
    text_object,
    write_buffer,
    jacpy_none,
    jacpy_ellipsis,
    jacpy_boolean,
    jacpy_int,
    jacpy_float,
    jacpy_complex,
    jacpy_tuple_new,
    jacpy_tuple_set_owned,
    jacpy_set_new,
    jacpy_long_from_bytes,
    jacpy_neg,
    jacpy_retain,
    jacpy_release
}
import from c {
    def jacpy_code_new(
        argcount: i64,
        posonlyargcount: i64,
        kwonlyargcount: i64,
        stacksize: i64,
        flags: i64,
        code: u64,
        consts: u64,
        names: u64,
        localsplusnames: u64,
        localspluskinds: u64,
        filename: u64,
        name: u64,
        qualname: u64,
        firstlineno: i64,
        linetable: u64,
        exceptiontable: u64
    ) -> u64;  def jacpy_slice_new(start: u64, stop: u64, step: u64) -> u64;
}

def constant_object(constant: PyObj) -> u64 {
    writer = constant_writer();
    try {
        return writer.write(constant);
    } finally {
        writer.close();
    }
}

# One conversion shares a filename object across its nested code objects, and
# equal constants (by compiler constant key) become one CPython object, as
# CPython's compiler merges them within a compilation unit.
obj constant_writer {
    has filename: str = "",
        filename_handle: u64 = 0,
        shared: dict[str, u64] = {};

    def write(constant: PyObj) -> u64 {
        if isinstance(constant, PyNoneType) {
            return required(jacpy_none());
        }
        if isinstance(constant, PyEllipsis) {
            return required(jacpy_ellipsis());
        }
        if isinstance(constant, PyBool) {
            return required(jacpy_boolean(i64(constant.val)));
        }
        key = constant_key(constant);
        existing = self.shared.get(key);
        if existing is not None {
            return jacpy_retain(existing);
        }
        created = self.create(constant);
        self.shared[key] = created;
        return jacpy_retain(created);
    }

    def create(constant: PyObj) -> u64 {
        if isinstance(constant, PyInt) {
            return required(jacpy_int(i64(constant.val)));
        }
        if isinstance(constant, PyBigInt) {
            return big_integer_object(constant);
        }
        if isinstance(constant, PyFloat) {
            return required(jacpy_float(f64(constant.val)));
        }
        if isinstance(constant, PyComplex) {
            return required(jacpy_complex(f64(constant.real), f64(constant.imag)));
        }
        if isinstance(constant, PyStr) {
            return text_object(constant.val);
        }
        if isinstance(constant, PyBytes) {
            return required(write_buffer(bytes(constant.val)));
        }
        if isinstance(constant, PyTuple) {
            return self.tuple_of(constant.items);
        }
        if isinstance(constant, PySet) and constant.frozen {
            items = self.tuple_of(list(constant.items.values()));
            try {
                return required(jacpy_set_new(items, 1));
            } finally {
                jacpy_release(items);
            }
        }
        if isinstance(constant, PySlice) {
            return self.slice_of(constant);
        }
        if isinstance(constant, PyCode) {
            return self.code_of(constant);
        }
        raise ValueError("Unsupported compiler constant: " + constant.t);
    }

    def tuple_of(items: list[PyObj]) -> u64 {
        result = required(jacpy_tuple_new(i64(len(items))));
        try {
            for (index, item) in enumerate(items) {
                checked(jacpy_tuple_set_owned(result, i64(index), self.write(item)));
            }
        } except Exception {
            jacpy_release(result);
            raise;
        }
        return result;
    }

    def slice_of(value: PySlice) -> u64 {
        start = self.write(value.start);
        try {
            stop = self.write(value.stop);
            try {
                step = self.write(value.step);
                try {
                    return required(jacpy_slice_new(start, stop, step));
                } finally {
                    jacpy_release(step);
                }
            } finally {
                jacpy_release(stop);
            }
        } finally {
            jacpy_release(start);
        }
    }

    def filename_of(filename: str) -> u64 {
        if self.filename_handle == 0 or self.filename != filename {
            handle = text_object(filename);
            jacpy_release(self.filename_handle);
            self.filename = filename;
            self.filename_handle = handle;
        }
        return self.filename_handle;
    }

    # CPython merges argument cells into their local slots, then appends the
    # remaining cells and free variables in compiler-assigned order.
    def code_of(code: PyCode) -> u64 {
        names: list[str] = [];
        kinds: list[int] = [];
        slots: dict[str, int] = {};
        local_kind = CO_FAST_LOCAL
            | (0 if code.flags & CO_OPTIMIZED else CO_FAST_HIDDEN);
        for name in code.varnames {
            slots[name] = len(names);
            names.append(name[6:] if name.startswith(".comp.") else name);
            kinds.append(local_kind);
        }
        for name in code.cellvars {
            if name in slots {
                kinds[slots[name]] |= CO_FAST_CELL;
            } else {
                names.append(name);
                kinds.append(CO_FAST_CELL);
            }
        }
        for name in code.freevars {
            names.append(name);
            kinds.append(CO_FAST_FREE);
        }
        owned: list[u64] = [];
        try {
            bytecode = held(owned, write_buffer(bytes(code.co_code)));
            consts = held(owned, self.tuple_of(code.consts));
            code_names = held(owned, text_tuple(code.names));
            localsplusnames = held(owned, text_tuple(names));
            localspluskinds = held(owned, write_buffer(bytes(kinds)));
            name = held(owned, text_object(code.name));
            qualname = held(owned, text_object(code.qualname));
            linetable = held(owned, write_buffer(bytes(code.linetable)));
            exceptiontable = held(owned, write_buffer(bytes(code.exceptiontable)));
            return required(
                jacpy_code_new(
                    i64(code.argcount),
                    i64(code.posonlyargcount),
                    i64(code.kwonlyargcount),
                    i64(code.stacksize),
                    i64(code.flags),
                    bytecode,
                    consts,
                    code_names,
                    localsplusnames,
                    localspluskinds,
                    self.filename_of(code.filename),
                    name,
                    qualname,
                    i64(code.firstlineno),
                    linetable,
                    exceptiontable
                )
            );
        } finally {
            for handle in owned {
                jacpy_release(handle);
            }
        }
    }

    def close {
        for handle in self.shared.values() {
            jacpy_release(handle);
        }
        self.shared = {};
        jacpy_release(self.filename_handle);
        self.filename_handle = 0;
    }
}

def held(owned: list[u64], handle: u64) -> u64 {
    owned.append(required(handle));
    return handle;
}

def text_tuple(values: list[str]) -> u64 {
    result = required(jacpy_tuple_new(i64(len(values))));
    try {
        for (index, value) in enumerate(values) {
            checked(jacpy_tuple_set_owned(result, i64(index), text_object(value)));
        }
    } except Exception {
        jacpy_release(result);
        raise;
    }
    return result;
}

# Compiler integers keep 15-bit digits; CPython reads the little-endian
# magnitude and applies the sign.
def big_integer_object(value: PyBigInt) -> u64 {
    magnitude: list[int] = [];
    accumulator = 0;
    bits = 0;
    for digit in value.digits {
        accumulator |= digit << bits;
        bits += 15;
        while bits >= 8 {
            magnitude.append(accumulator & 255);
            accumulator >>= 8;
            bits -= 8;
        }
    }
    if bits > 0 {
        magnitude.append(accumulator & 255);
    }
    data = required(write_buffer(bytes(magnitude)));
    try {
        result = required(jacpy_long_from_bytes(data));
    } finally {
        jacpy_release(data);
    }
    if not value.negative {
        return result;
    }
    try {
        return required(jacpy_neg(result));
    } finally {
        jacpy_release(result);
    }
}
