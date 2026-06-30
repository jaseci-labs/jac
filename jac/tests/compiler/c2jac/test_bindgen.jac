"""cbindgen phase-exit tests.

Phase 0 (function prototypes) was shipped without an output test; this file
locks that down *and* covers Phase 1 (named integer constants — enum
enumerators + object-like #define ints → `glob NAME: int = N;`). Bindings are
native-FFI `.na.jac` (an `import from <lib>` block), so we assert on structure
rather than recompiling — module resolution of the foreign lib is out of scope.
"""

import from tests.compiler.c2jac.support { read_fixture }
import from jaclang.compiler.c2jac.bindgen { bindings_from_source }

def _bind(
    name: str, lib: str, allow: list | None = None, block: list | None = None
) -> tuple {
    # (jac_str, report) for a fixture header under fixtures/bindgen/.
    return bindings_from_source(
        read_fixture(name), name.rsplit("/", 1)[-1], lib, allow=allow, block=block
    );
}

# ---------------------------------------------------------------------------- #
# Phase 0 — extern function prototypes                                          #
# ---------------------------------------------------------------------------- #
test "Phase 0 binds every primitive-width prototype with the right FFI types" {
    (out, rep) = _bind("bindgen/test.h", "tk");
    assert "import from tk {" in out , out;
    assert "def tk_add(a: i32, b: i32) -> i32;" in out , out;
    assert "def tk_scale(x: f64, k: f32) -> f64;" in out , out;
    assert "def tk_clamp(lo: i16, hi: i16, v: i32) -> i16;" in out , out;
    assert rep.functions == 7 , f"expected 7 functions, got {rep.functions}";
}

test "Phase 0 maps the const char* string idiom and byte buffers" {
    (out, rep) = _bind("bindgen/test.h", "tk");
    # const char* (no signedness) → str; (unsigned) char* buffer → bytes.
    assert "def tk_name() -> str;" in out , out;
    assert "def tk_checksum(buf: bytes, n: u64) -> u64;" in out , out;
}

test "Phase 0 drops a (void) param list and binds an opaque pointer return as int" {
    (out, rep) = _bind("bindgen/test.h", "tk");
    assert "def tk_alloc(size: u64) -> int;" in out , out;  # void* return → int
}

test "Phase 0 emits *rest for a variadic and counts it" {
    (out, rep) = _bind("bindgen/test.h", "tk");
    assert "def tk_logf(fmt: str, *rest) -> i32;" in out , out;
    assert rep.variadic == 1 , f"expected 1 variadic, got {rep.variadic}";
}

# ---------------------------------------------------------------------------- #
# Phase 1 — named integer constants                                            #
# ---------------------------------------------------------------------------- #
test "Phase 1 binds enum enumerators with C's implicit-sequential rule" {
    (out, rep) = _bind("bindgen/consts.h", "cs");
    assert "glob ST_IDLE: int = 0;" in out , out;
    assert "glob ST_BUSY: int = 5;" in out , out;  # explicit value
    assert "glob ST_DONE: int = 6;" in out , out;  # resumes from 5 → 6
}

test "Phase 1 binds enumerators from a typedef'd enum" {
    (out, rep) = _bind("bindgen/consts.h", "cs");
    assert "glob LVL_LO: int = 0;" in out , out;
    assert "glob LVL_HI: int = 10;" in out , out;
}

test "Phase 1 binds object-like int #define macros (hex normalized, negatives)" {
    (out, rep) = _bind("bindgen/consts.h", "cs");
    assert "glob BUF_CAP: int = 256;" in out , out;
    assert "glob MASK_HEX: int = 255;" in out , out;  # 0xFF → decimal
    assert "glob NEG_ONE: int = -1;" in out , out;
}

test "Phase 1 skips non-int and function-like macros" {
    (out, rep) = _bind("bindgen/consts.h", "cs");
    assert "GREETING" not in out , out;  # string macro
    assert "SQUARE" not in out , out;  # function-like macro
}

test "Phase 1 counts constants and still binds the coexisting function" {
    (out, rep) = _bind("bindgen/consts.h", "cs");
    # 3 enum (Status) + 2 enum (Level) + 3 macro (BUF_CAP/MASK_HEX/NEG_ONE) = 8.
    assert rep.constants == 8 , f"expected 8 constants, got {rep.constants}";
    assert rep.functions == 1 , f"expected 1 function, got {rep.functions}";
    assert "def cs_classify(s: i32) -> i32;" in out , out;
}

# ---------------------------------------------------------------------------- #
# allow / block filters apply to constants too                                 #
# ---------------------------------------------------------------------------- #
test "allowlist restricts constants to the named symbols" {
    (out, rep) = _bind("bindgen/consts.h", "cs", allow=["ST_BUSY", "BUF_CAP"]);
    assert "glob ST_BUSY: int = 5;" in out , out;
    assert "glob BUF_CAP: int = 256;" in out , out;
    assert "ST_IDLE" not in out , out;
    assert "LVL_HI" not in out , out;
}

test "blocklist drops named constants" {
    (out, rep) = _bind("bindgen/consts.h", "cs", block=["MASK_HEX"]);
    assert "MASK_HEX" not in out , out;
    assert "glob BUF_CAP: int = 256;" in out , out;
}

# ---------------------------------------------------------------------------- #
# Phase 2 — fixed-width + typedef scalar resolution                            #
# ---------------------------------------------------------------------------- #
test "Phase 2 maps fixed-width / size typedefs by name" {
    (out, rep) = _bind("bindgen/stdint.h", "si");
    # uint8_t* buffer → bytes; size_t → u64; ssize_t → i64.
    assert "def si_read(fd: i32, buf: bytes, n: u64) -> i64;" in out , out;
}

test "Phase 2 name map beats a deliberately-wrong-width typedef" {
    (out, rep) = _bind("bindgen/stdint.h", "si");
    # uint32_t is typedef'd to `unsigned long` (u64) in the fixture, but the
    # fixed-width name map must still bind its return as u32 (not u64).
    assert "def si_hash(data: bytes, n: u64) -> u32;" in out , out;
}

test "Phase 2 resolves a user scalar typedef alias through the typedef map" {
    (out, rep) = _bind("bindgen/stdint.h", "si");
    assert "def si_scale(x: f64, k: f64) -> f64;" in out , out;  # real_t → double → f64
}

# ---------------------------------------------------------------------------- #
# Phase 3 — struct layout bindings                                              #
# ---------------------------------------------------------------------------- #
test "Phase 3 emits obj for a plain named struct with int fields" {
    (out, rep) = _bind("bindgen/structs.h", "geo");
    assert "obj Point { has x: i32 = 0; has y: i32 = 0; }" in out , out;
}

test "Phase 3 emits obj for a typedef'd anonymous struct with float fields" {
    (out, rep) = _bind("bindgen/structs.h", "geo");
    assert "obj Color { has r: f32 = 0.0; has g: f32 = 0.0; has b: f32 = 0.0; }" in out , out;
}

test "Phase 3 resolves struct-by-value params to the struct name" {
    (out, rep) = _bind("bindgen/structs.h", "geo");
    assert "def pt_add(a: Point, b: Point) -> Point;" in out , out;
    assert "def pt_dot(a: Point, b: Point) -> i32;" in out , out;
}

test "Phase 3 resolves typedef'd struct params to the typedef name" {
    (out, rep) = _bind("bindgen/structs.h", "geo");
    assert "def color_blend(a: Color, b: Color, t: f32) -> Color;" in out , out;
}

test "Phase 3 keeps struct-pointer params as int" {
    (out, rep) = _bind("bindgen/structs.h", "geo");
    assert "def pt_translate(p: int, dx: i32, dy: i32) -> None;" in out , out;
}

test "Phase 3 counts structs and functions separately in the report" {
    (out, rep) = _bind("bindgen/structs.h", "geo");
    assert rep.structs == 2 , f"expected 2 structs, got {rep.structs}";
    assert rep.functions == 4 , f"expected 4 functions, got {rep.functions}";
}

test "Phase 3 struct blocks appear before function bindings" {
    (out, rep) = _bind("bindgen/structs.h", "geo");
    obj_pos = out.index("obj Point");
    fn_pos = out.index("def pt_add");
    assert obj_pos < fn_pos , "struct obj must appear before function defs";
}

test "Phase 3 blocklist suppresses a struct" {
    (out, rep) = _bind("bindgen/structs.h", "geo", block=["Point"]);
    assert "obj Point" not in out , out;
    assert "obj Color" in out , out;
}
