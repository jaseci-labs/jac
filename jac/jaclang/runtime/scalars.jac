import from jaclang.runtime.object_model { make_object }

glob F32_MAX: float = 3.4028234663852886e38,
     F32_OVERFLOW: float = 3.4028236692093846e38,
     F64_MAX: float = 1.7976931348623157e308;

@make_object
class ScalarShape {
    has name: str,
        width: int,
        signed: bool = False,
        is_float: bool = False,
        sized: bool = False;

    def size_bytes(self: ScalarShape) -> int {
        return max(1, self.width // 8);
    }

    def align(self: ScalarShape) -> int {
        return self.size_bytes();
    }

    def is_int_kind(self: ScalarShape) -> bool {
        return not self.is_float;
    }
}

def numeric_shapes -> list[ScalarShape] {
    return [
        ScalarShape(name="int", width=64, signed=True),
        ScalarShape(name="float", width=64, is_float=True),
        ScalarShape(name="bool", width=1),
        ScalarShape(name="i8", width=8, signed=True, sized=True),
        ScalarShape(name="u8", width=8, sized=True),
        ScalarShape(name="i16", width=16, signed=True, sized=True),
        ScalarShape(name="u16", width=16, sized=True),
        ScalarShape(name="i32", width=32, signed=True, sized=True),
        ScalarShape(name="u32", width=32, sized=True),
        ScalarShape(name="i64", width=64, signed=True, sized=True),
        ScalarShape(name="u64", width=64, sized=True),
        ScalarShape(name="f32", width=32, is_float=True, sized=True),
        ScalarShape(name="f64", width=64, is_float=True, sized=True)
    ];
}

def shape_of(name: str) -> ScalarShape | None {
    for shape in numeric_shapes() {
        if shape.name == name {
            return shape;
        }
    }
    return None;
}

def is_sized(name: str) -> bool {
    shape = shape_of(name);
    return shape is not None and shape.sized;
}

def sized_int_names -> list[str] {
    return [
        s.name
        for s in numeric_shapes()
        if s.sized and not s.is_float
    ];
}

def sized_float_names -> list[str] {
    return [
        s.name
        for s in numeric_shapes()
        if s.sized and s.is_float
    ];
}

def sized_scalar_names -> list[str] {
    return [
        s.name
        for s in numeric_shapes()
        if s.sized
    ];
}

def shape_range(shape: ScalarShape) -> tuple[int, int] {
    if not shape.sized or shape.is_float {
        raise ValueError(f"{shape.name} is not a sized integer type");
    }
    if shape.signed {
        half = 1 << (shape.width - 1);
        return (-half, half - 1);
    }
    return (0, (1 << shape.width) - 1);
}

def range_of(name: str) -> tuple[int, int] {
    shape = shape_of(name);
    if shape is None {
        raise KeyError(name);
    }
    return shape_range(shape);
}

def shape_float_max(shape: ScalarShape) -> float {
    if not shape.is_float {
        raise ValueError(f"{shape.name} is not a float type");
    }
    if shape.width == 32 {
        return F32_MAX;
    }
    return F64_MAX;
}

def float_max(name: str) -> float {
    shape = shape_of(name);
    if shape is None {
        raise KeyError(name);
    }
    return shape_float_max(shape);
}

def shape_literal_fits(shape: ScalarShape, value: int | float) -> bool {
    if not shape.sized {
        return False;
    }
    if shape.is_float {
        if not isinstance(value, (int, float)) {
            return False;
        }
        if shape.width == 32 {
            if value < 0 {
                return -F32_OVERFLOW < value;
            }
            return value < F32_OVERFLOW;
        }
        if value < 0 {
            return -F64_MAX <= value;
        }
        return value <= F64_MAX;
    }
    if isinstance(value, float) {
        return False;
    }
    (lo, hi) = shape_range(shape);
    return lo <= int(value) <= hi;
}

def literal_fits(name: str, value: int | float) -> bool {
    shape = shape_of(name);
    if shape is None {
        return False;
    }
    return shape_literal_fits(shape, value);
}

def shapes_widen_to(s: ScalarShape, d: ScalarShape) -> bool {
    if s.name == d.name {
        return True;
    }
    if s.name == "bool" {
        return True;
    }
    if d.name == "bool" {
        return False;
    }
    if s.is_float {
        return d.is_float and d.width >= s.width;
    }
    if d.is_float {
        return d.width >= 64 or s.width <= d.width // 2;
    }
    if s.signed == d.signed {
        return d.width >= s.width;
    }
    return d.signed and d.width > s.width;
}

def widens_to(src: str, dst: str) -> bool {
    if src == dst {
        return True;
    }
    s = shape_of(src);
    d = shape_of(dst);
    if s is None or d is None {
        return False;
    }
    return shapes_widen_to(s, d);
}

def shapes_unify(a: ScalarShape, b: ScalarShape) -> ScalarShape | None {
    if shapes_widen_to(a, b) {
        return b;
    }
    if shapes_widen_to(b, a) {
        return a;
    }
    return None;
}

def unify(a: str, b: str) -> str | None {
    if widens_to(a, b) {
        return b;
    }
    if widens_to(b, a) {
        return a;
    }
    return None;
}

def shape_wrap(shape: ScalarShape, value: int) -> int {
    mask = (1 << shape.width) - 1;
    out = int(value) & mask;
    if shape.signed and out >= (1 << (shape.width - 1)) {
        out -= 1 << shape.width;
    }
    return out;
}

def wrap_value(name: str, value: int) -> int {
    shape = shape_of(name);
    if shape is None {
        raise KeyError(name);
    }
    return shape_wrap(shape, value);
}
