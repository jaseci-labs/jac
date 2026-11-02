glob F32_MAX: float = 3.4028234663852886e38,
     F32_OVERFLOW: float = 3.4028236692093846e38,
     F64_MAX: float = 1.7976931348623157e308;

obj ScalarShape {
    has name: str,
        width: int,
        signed: bool = False,
        is_float: bool = False,
        sized: bool = False;

    def size_bytes -> int;
    def align -> int;
    def is_int_kind -> bool;
}

def numeric_shapes -> list[ScalarShape];

def shape_of(name: str) -> ScalarShape | None;

def is_sized(name: str) -> bool;

def sized_int_names -> list[str];

def sized_float_names -> list[str];

def sized_scalar_names -> list[str];

def shape_range(shape: ScalarShape) -> tuple[int, int];

def range_of(name: str) -> tuple[int, int];

def shape_float_max(shape: ScalarShape) -> float;

def float_max(name: str) -> float;

def shape_literal_fits(shape: ScalarShape, value: int | float) -> bool;

def literal_fits(name: str, value: int | float) -> bool;

def shapes_widen_to(s: ScalarShape, d: ScalarShape) -> bool;

def widens_to(src: str, dst: str) -> bool;

def shapes_unify(a: ScalarShape, b: ScalarShape) -> ScalarShape | None;

def unify(a: str, b: str) -> str | None;

def shape_wrap(shape: ScalarShape, value: int) -> int;

def wrap_value(name: str, value: int) -> int;
