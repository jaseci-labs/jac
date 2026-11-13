impl round_f32(value: float) -> float {
    try {
        return _F32.unpack(_F32.pack(value))[0];
    } except OverflowError {
        return math.copysign(math.inf, value);
    }
}

impl _mk_check(lo: int, hi: int) -> any {
    def check(v: int) -> int {
        if lo <= v <= hi {
            return v;
        }
        raise OverflowError(OVERFLOW_MESSAGE);
    }
    return check;
}

impl _mk_shl(lo: int, hi: int, width: int) -> any {
    def shl(a: int, b: int) -> int {
        if b < 0 or b >= width {
            raise OverflowError(SHIFT_MESSAGE);
        }
        v = a << b;
        if lo <= v <= hi {
            return v;
        }
        raise OverflowError(OVERFLOW_MESSAGE);
    }
    return shl;
}

impl _mk_shr(width: int) -> any {
    def shr(a: int, b: int) -> int {
        if b < 0 or b >= width {
            raise OverflowError(SHIFT_MESSAGE);
        }
        return a >> b;
    }
    return shr;
}

impl _mk_pow(lo: int, hi: int, width: int) -> any {
    def ipow(a: int, b: int) -> any {
        if b < 0 {
            return float(a) ** float(b);
        }
        if abs(a) >= 2 and b >= width {
            raise OverflowError(OVERFLOW_MESSAGE);
        }
        v = a ** b;
        if lo <= v <= hi {
            return v;
        }
        raise OverflowError(OVERFLOW_MESSAGE);
    }
    return ipow;
}

impl _mk_invert(mask: int) -> any {
    def invert(a: int) -> int {
        return (~a) & mask;
    }
    return invert;
}

impl _mk_int_class(name: str, lo: int, hi: int) -> type {
    def __new__(cls: type, x: any = 0) -> int {
        if isinstance(x, (bool, int, float)) {
            v = int(x);
        } else {
            raise TypeError(
                f"{name}() argument must be a number, not '{type(x).__name__}'"
            );
        }
        if lo <= v <= hi {
            return v;
        }
        raise OverflowError(OVERFLOW_MESSAGE);
    }

    def wrap(x: any) -> int {
        return wrap_value(name, int(x));
    }
    return type(
        name,
        (int, ),
        {
            "__new__": __new__,
            "wrap": staticmethod(wrap),
            "MIN": lo,
            "MAX": hi,
            "__jac_sized__": name,
            "__module__": "builtins"
        }
    );
}

impl _mk_float_class(name: str, narrow: bool) -> type {
    def __new__(cls: type, x: any = 0.0) -> float {
        if isinstance(x, (bool, int, float)) {
            v = float(x);
        } else {
            raise TypeError(
                f"{name}() argument must be a number, not '{type(x).__name__}'"
            );
        }
        return round_f32(v) if narrow else v;
    }
    return type(
        name,
        (float, ),
        {"__new__": __new__, "__jac_sized__": name, "__module__": "builtins"}
    );
}

impl _fw_wrapping(name: str, op: str, a: any, b: any = 0) -> int {
    row = shape_of(name);
    if row is None {
        raise TypeError(f"{name} is not a fixed-width type");
    }
    width = row.width;
    if op == "+" {
        raw = int(a) + int(b);
    } elif op == "-" {
        raw = int(a) - int(b);
    } elif op == "*" {
        raw = int(a) * int(b);
    } elif op == "<<" {
        raw = int(a) << (int(b) & (width - 1));
    } elif op == "neg" {
        raw = -int(a);
    } else {
        raise TypeError(f"unsupported wrapping operator {op}");
    }
    return wrap_value(name, raw);
}

impl _build_family {
    for row in numeric_shapes() {
        if not row.sized {
            continue;
        }
        if row.is_float {
            SIZED_TYPES[row.name] = _mk_float_class(row.name, row.width == 32);
            continue;
        }
        (lo, hi) = range_of(row.name);
        FW[f"_fw_ck_{row.name}"] = _mk_check(lo, hi);
        FW[f"_fw_shl_{row.name}"] = _mk_shl(lo, hi, row.width);
        FW[f"_fw_shr_{row.name}"] = _mk_shr(row.width);
        FW[f"_fw_pow_{row.name}"] = _mk_pow(lo, hi, row.width);
        if not row.signed {
            FW[f"_fw_inv_{row.name}"] = _mk_invert(hi);
        }
        SIZED_TYPES[row.name] = _mk_int_class(row.name, lo, hi);
    }
    FW["_fw_r_f32"] = round_f32;
    FW["_fw_wrapping"] = _fw_wrapping;
}

impl json_wire_form(name: str, value: any) -> any {
    row = shape_of(name);
    if row is None or not row.sized or row.is_float or row.width < 64 {
        return value;
    }
    n = int(value);
    if n > JS_SAFE_INT or n < -JS_SAFE_INT {
        return str(n);
    }
    return n;
}

impl json_wire_read(name: str, value: any) -> any {
    row = shape_of(name);
    if isinstance(value, str) {
        return SIZED_TYPES[name](
            float(value) if (row is not None and row.is_float) else int(value)
        );
    }
    return SIZED_TYPES[name](value);
}

impl _wrapping_unavailable(name: str) -> any {
    def stub(*args: any, **kwargs: any) -> any {
        raise TypeError(
            f"{name} must be called directly on fixed-width operands; "
            "it cannot be taken as a value"
        );
    }
    return stub;
}

impl __getattr__(name: str) -> object {
    hit = FW.get(name, None);
    if hit is not None {
        return hit;
    }
    cast = SIZED_TYPES.get(name, None);
    if cast is not None {
        return cast;
    }
    if name.startswith("wrapping_") {
        return _wrapping_unavailable(name);
    }
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}");
}
