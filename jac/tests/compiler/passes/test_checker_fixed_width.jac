"""Check-time contract for the fixed-width numeric types (#8532).

`i8 u8 i16 u16 i32 u32 i64 u64 f32 f64` are real types with one lattice:
widening is implicit only when it is value-preserving, everything else is a
checked cast. The checker enforces that contract and reports it with four
codes, each pinned here with its line and column:

  E1126  an int literal outside the target's range
  E1127  a narrowing (or sign-changing) implicit conversion
  E1128  a binary operator whose operands have no common fixed-width type
  E1129  unary minus on an unsigned operand

The same program must check identically on the server and native lanes.
"""

import os;
import from tests.support { TESTS_DIR }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FW_CODES: tuple = ("E1126", "E1127", "E1128", "E1129", "E1130"),
     VIRTUAL_PATH: str = os.path.join(
         TESTS_DIR, "compiler", "passes", "fixtures", "checker", "_fw_inline.jac"
     );

"""Type-check `source` on one lane; return (code, line, col) per diagnostic."""
def check(source: str, space: str = "server") -> list[tuple] {
    prog = JacProgram();
    prog.compile(
        file_path=VIRTUAL_PATH,
        use_str=source,
        options=CompileOptions(no_cgen=True, force_codespace=space)
    );
    out: list[tuple] = [];
    for alrt in prog.errors_had {
        if alrt.code is None {
            continue;
        }
        out.append((alrt.code.code, alrt.loc.first_line, alrt.loc.col_start));
    }
    return out;
}

def fw_only(diags: list[tuple]) -> list[tuple] {
    return [
        d
        for d in diags
        if d[0] in FW_CODES
    ];
}

def assert_clean(source: str) {
    diags = check(source);
    assert diags == [] , f"expected a clean check, got {diags}";
}

# ── literal range (E1126) ─────────────────────────────────────────
test "int literal above the range of u8 is E1126 at the literal" {
    src = "with entry {\n    x: u8 = 300;\n}\n";
    diags = check(src);
    assert diags == [("E1126", 2, 13)] , diags;
}

test "negative literal into u8 is E1126" {
    src = "with entry {\n    x: u8 = -1;\n}\n";
    assert check(src) == [("E1126", 2, 13)];
}

test "boundary literals fit: i8 = -128, i8 = 127, u16 = 65535, u64 = 2**64-1" {
    assert_clean(
        "with entry {\n"
        "    a: i8 = -128;\n"
        "    b: i8 = 127;\n"
        "    c: u16 = 65535;\n"
        "    d: u64 = 18446744073709551615;\n"
        "    e: i64 = -9223372036854775808;\n"
        "}\n"
    );
}

test "one past the boundary is E1126: i8 = 128, i8 = -129, u64 = 2**64" {
    src = (
        "with entry {\n"
        "    a: i8 = 128;\n"
        "    b: i8 = -129;\n"
        "    c: u64 = 18446744073709551616;\n"
        "}\n"
    );
    assert fw_only(check(src))
        == [("E1126", 2, 13), ("E1126", 3, 13), ("E1126", 4, 14)];
}

test "literal range applies to call arguments, returns, and has defaults" {
    src = (
        "def takes_u8(x: u8) -> u8 {\n"
        "    return 256;\n"
        "}\n"
        "obj Pixel {\n"
        "    has r: u8 = 999;\n"
        "}\n"
        "with entry {\n"
        "    takes_u8(300);\n"
        "}\n"
    );
    assert fw_only(check(src))
        == [("E1126", 2, 12), ("E1126", 5, 17), ("E1126", 8, 14)];
}

test "a float literal is accepted where the type can hold it" {
    assert_clean("with entry {\n    a: f32 = 0.1;\n    b: f64 = 1e300;\n}\n");
    assert_clean("with entry {\n    a: f32 = 3.4e38;\n    b: f32 = -3.4e38;\n}\n");
}

test "a float literal past the type's range is E1130, not a silent inf" {
    src = (
        "with entry {\n"
        "    a: f32 = 1e60;\n"
        "    b: f64 = 1e400;\n"
        "    c: f32 = 340282400000000000000000000000000000000000.0;\n"
        "}\n"
    );
    assert fw_only(check(src))
        == [("E1130", 2, 14), ("E1130", 3, 14), ("E1130", 4, 14)] , (
        "a literal that overflows the target float becomes inf at run time "
        "with nothing said at check time; precision loss inside the range "
        "stays accepted, overflow past it does not"
    );
}

# ── narrowing (E1127) ─────────────────────────────────────────────
test "narrowing a sized value into a narrower parameter is E1127" {
    src = (
        "def takes_u8(x: u8) -> int {\n    return 0;\n}\n"
        "def takes_i8(x: i8) -> int {\n    return 0;\n}\n"
        "with entry {\n"
        "    a: i8 = 1;\n"
        "    b: i64 = 1;\n"
        "    n: int = 1;\n"
        "    takes_u8(a);\n"
        "    takes_i8(b);\n"
        "    takes_i8(n);\n"
        "}\n"
    );
    assert fw_only(check(src))
        == [("E1127", 11, 14), ("E1127", 12, 14), ("E1127", 13, 14)];
}

test "int into a sized annotation is E1127, sized into int is fine" {
    src = (
        "with entry {\n"
        "    n: int = 5;\n"
        "    w: i32 = n;\n"
        "    m: int = w;\n"
        "}\n"
    );
    assert fw_only(check(src)) == [("E1127", 3, 14)];
}

test "a unified result wider than the annotation is E1127" {
    src = (
        "with entry {\n"
        "    a: i8 = 1;\n"
        "    b: i64 = 2;\n"
        "    s: i8 = a + b;\n"
        "}\n"
    );
    assert fw_only(check(src)) == [("E1127", 4, 13)];
}

test "T op int yields int, so w = w + n narrows (E1127) while w = w + 1 is fine" {
    src = (
        "with entry {\n"
        "    w: i32 = 1;\n"
        "    n: int = 2;\n"
        "    w = w + 1;\n"
        "    w = w + n;\n"
        "    w += 1;\n"
        "    w += n;\n"
        "}\n"
    );
    assert fw_only(check(src)) == [("E1127", 5, 9), ("E1127", 7, 10)];
}

test "the widening lattice is implicit" {
    assert_clean(
        "def takes_i64(x: i64) -> int {\n    return 0;\n}\n"
        "def takes_int(x: int) -> int {\n    return 0;\n}\n"
        "def takes_f64(x: f64) -> int {\n    return 0;\n}\n"
        "def takes_i16(x: i16) -> int {\n    return 0;\n}\n"
        "def takes_float(x: float) -> int {\n    return 0;\n}\n"
        "def takes_f32(x: f32) -> int {\n    return 0;\n}\n"
        "with entry {\n"
        "    a: i8 = 1;\n"
        "    b: u64 = 1;\n"
        "    c: f32 = 1.0;\n"
        "    d: u8 = 1;\n"
        "    e: u16 = 1;\n"
        "    f: float = 1.0;\n"
        "    g: i32 = 1;\n"
        "    ok: bool = True;\n"
        "    takes_i64(a);\n"
        "    takes_f64(c);\n"
        "    takes_i16(d);\n"
        "    takes_f32(e);\n"
        "    takes_f64(g);\n"
        "    takes_float(c);\n"
        "    takes_f64(f);\n"
        "    takes_i16(ok);\n"
        "    takes_float(a);\n"
        "    h: f64 = c;\n"
        "}\n"
    );
}

test "u64 into int is E1127: int is a signed 64-bit machine type" {
    src = (
        "def takes_int(x: int) -> int {\n    return 0;\n}\n"
        "with entry {\n"
        "    b: u64 = 1;\n"
        "    takes_int(b);\n"
        "    n: int = b;\n"
        "}\n"
    );
    assert fw_only(check(src)) == [("E1127", 6, 15), ("E1127", 7, 14)] , (
        "u64 -> int has to be refused for the same reason u64 -> i64 is: the "
        "native lane lowers `int` as i64, so a u64 past 2^63 arrives negative "
        "there while the server keeps it positive, with no diagnostic on "
        "either lane"
    );
}

test "int and i64 are interchangeable in the lattice, as are float and f64" {
    assert_clean(
        "def takes_i64(x: i64) -> int {\n    return 0;\n}\n"
        "def takes_f64(x: f64) -> int {\n    return 0;\n}\n"
        "def takes_float(x: float) -> int {\n    return 0;\n}\n"
        "with entry {\n"
        "    n: int = 1;\n"
        "    w: i64 = 1;\n"
        "    takes_i64(n);\n"
        "    takes_f64(n);\n"
        "    takes_float(n);\n"
        "    takes_f64(w);\n"
        "    takes_float(w);\n"
        "}\n"
    );
}

test "same-width sign change and lossy float rows are E1127" {
    src = (
        "def takes_i8(x: i8) -> int {\n    return 0;\n}\n"
        "def takes_f32(x: f32) -> int {\n    return 0;\n}\n"
        "def takes_i32(x: i32) -> int {\n    return 0;\n}\n"
        "with entry {\n"
        "    a: u8 = 1;\n"
        "    b: i64 = 1;\n"
        "    c: f64 = 1.0;\n"
        "    d: float = 1.0;\n"
        "    e: i32 = 1;\n"
        "    f: u32 = 1;\n"
        "    takes_i8(a);\n"
        "    takes_f32(b);\n"
        "    takes_f32(c);\n"
        "    takes_f32(d);\n"
        "    takes_f32(e);\n"
        "    takes_i32(f);\n"
        "}\n"
    );
    assert fw_only(check(src))
        == [
            ("E1127", 17, 14),
            ("E1127", 18, 15),
            ("E1127", 19, 15),
            ("E1127", 20, 15),
            ("E1127", 21, 15),
            ("E1127", 22, 15)
        ];
}

test "a float-kind into an int-kind stays the generic parameter error, not E1127" {
    src = (
        "def takes_i8(x: i8) -> int {\n    return 0;\n}\n"
        "def takes_str(x: str) -> int {\n    return 0;\n}\n"
        "with entry {\n"
        "    f: float = 1.0;\n"
        "    a: i8 = 1;\n"
        "    takes_i8(f);\n"
        "    takes_str(a);\n"
        "}\n"
    );
    diags = check(src);
    assert fw_only(diags) == [] , diags;
    assert [
        d
        for d in diags
        if d[0] == "E1053"
    ]
        == [("E1053", 10, 14), ("E1053", 11, 15)] , diags;
}

test "explicit casts and wrap are accepted everywhere narrowing is refused" {
    assert_clean(
        "def takes_u8(x: u8) -> int {\n    return 0;\n}\n"
        "with entry {\n"
        "    n: int = 300;\n"
        "    a: i8 = 1;\n"
        "    b: u8 = u8(n);\n"
        "    c: u8 = u8.wrap(n);\n"
        "    d: i8 = i8(a);\n"
        "    takes_u8(u8(a));\n"
        "    e: f32 = f32(1.5);\n"
        "    f: i32 = i32(e);\n"
        "    g: int = int(b);\n"
        "    h: float = float(c);\n"
        "}\n"
    );
}

test "a literal cast argument out of range is E1126" {
    src = "with entry {\n    x: u8 = u8(300);\n    y: i8 = i8(-129);\n}\n";
    assert fw_only(check(src)) == [("E1126", 2, 16), ("E1126", 3, 16)];
}

# ── operands (E1128) ──────────────────────────────────────────────
test "mixing signedness at one width in arithmetic or comparison is E1128" {
    src = (
        "with entry {\n"
        "    a: u8 = 1;\n"
        "    b: i8 = 1;\n"
        "    c: u64 = 1;\n"
        "    d: i64 = 1;\n"
        "    e: i32 = 1;\n"
        "    f: u32 = 1;\n"
        "    x = a + b;\n"
        "    y = c < d;\n"
        "    z = e == f;\n"
        "}\n"
    );
    assert fw_only(check(src)) == [("E1128", 8, 9), ("E1128", 9, 9), ("E1128", 10, 9)];
}

test "a 64-bit int with f32 needs a cast (E1128); i16 + f32 unifies to f32" {
    src = (
        "with entry {\n"
        "    a: i64 = 1;\n"
        "    b: f32 = 1.0;\n"
        "    c: i16 = 1;\n"
        "    x = a + b;\n"
        "    y: f32 = c + b;\n"
        "    z: f32 = f32(a) + b;\n"
        "}\n"
    );
    assert fw_only(check(src)) == [("E1128", 5, 9)];
}

test "an in-range literal adopts the sized operand; out of range is E1126" {
    src = (
        "with entry {\n"
        "    a: u8 = 1;\n"
        "    b: i32 = 1;\n"
        "    x: u8 = a + 1;\n"
        "    y: i32 = 1 + b;\n"
        "    z = a + 300;\n"
        "    w: u8 = a & 255;\n"
        "    v: u8 = a >> 1;\n"
        "    u: i32 = b << 3;\n"
        "    q: bool = a == 0;\n"
        "}\n"
    );
    assert fw_only(check(src)) == [("E1126", 6, 13)];
}

test "division on any int-kind yields float; floor-div, mod and pow keep the type" {
    assert_clean(
        "with entry {\n"
        "    a: u32 = 7;\n"
        "    b: u32 = 2;\n"
        "    x: float = a / b;\n"
        "    y: u32 = a // b;\n"
        "    z: u32 = a % b;\n"
        "    p: u32 = a ** 2;\n"
        "    q: float = a ** -1;\n"
        "}\n"
    );
}

test "augmented assignment on a sized target unifies like the binary form" {
    src = (
        "with entry {\n"
        "    a: u8 = 1;\n"
        "    b: i8 = 1;\n"
        "    a += 1;\n"
        "    a += b;\n"
        "}\n"
    );
    assert fw_only(check(src)) == [("E1128", 5, 5)];
}

# ── unsigned negation (E1129) ─────────────────────────────────────
test "unary minus on an unsigned operand is E1129" {
    src = "with entry {\n    a: u32 = 1;\n    b = -a;\n    c: u32 = ~a;\n}\n";
    assert fw_only(check(src)) == [("E1129", 3, 9)];
}

# ── type-level surface ───────────────────────────────────────────
test "MIN, MAX, wrap and the wrapping_* builtins type-check with precise types" {
    assert_clean(
        "with entry {\n"
        "    lo: i8 = i8.MIN;\n"
        "    hi: u16 = u16.MAX;\n"
        "    w: u8 = u8.wrap(300);\n"
        "    a: i8 = 100;\n"
        "    s: i8 = wrapping_add(a, a);\n"
        "    d: i8 = wrapping_sub(a, a);\n"
        "    m: i8 = wrapping_mul(a, 2);\n"
        "    n: i8 = wrapping_neg(a);\n"
        "    l: i8 = wrapping_shl(a, 1);\n"
        "    t: type = i8;\n"
        "}\n"
    );
}

test "wrapping_* over mismatched operands is E1128" {
    src = "with entry {\n    a: i8 = 1;\n    b: u8 = 1;\n    s = wrapping_add(a, b);\n}\n";
    assert fw_only(check(src)) == [("E1128", 4, 9)];
}

# ── lane parity ───────────────────────────────────────────────────
test "the native lane reports exactly the diagnostics the server lane reports" {
    src = (
        "def takes_i8(x: i8) -> i8 {\n    return x;\n}\n"
        "with entry {\n"
        "    a: u8 = 300;\n"
        "    b: u8 = 1;\n"
        "    c: i8 = 1;\n"
        "    n: int = 1;\n"
        "    d = b + c;\n"
        "    e = -b;\n"
        "    takes_i8(n);\n"
        "    w: i32 = 2147483647;\n"
        "    w = w + 1;\n"
        "    ok: i8 = takes_i8(c);\n"
        "}\n"
    );
    sv = fw_only(check(src, "server"));
    na = fw_only(check(src, "native"));
    assert sv
        == [
            ("E1126", 5, 13),
            ("E1128", 9, 9),
            ("E1129", 10, 9),
            ("E1127", 11, 14)
        ] , sv;
    assert na == sv , f"native {na} != server {sv}";
}

# ── extern (clib) struct construction ────────────────────────────
test "sized fields of an extern struct are enforced at construction on every lane" {
    src = (
        'import from m {\n'
        '    obj Color { has r: u8, g: u8, b: u8, a: u8; }\n'
        '}\n'
        'def paint(x: int) -> Color {\n'
        '    c = Color(r=x, g=3, b=300, a=u8(x));\n'
        '    return Color(x, 1, 2, 3);\n'
        '}\n'
    );
    expected = [("E1127", 5, 17), ("E1126", 5, 27), ("E1127", 6, 18)];
    assert fw_only(check(src)) == expected , check(src);
    assert fw_only(check(src, "native")) == expected , check(src, "native");
}

test "overloaded extern signatures resolve with literal adoption and casts" {
    src = (
        'import from "libc.so.6" {\n'
        '    def memset(s: int, c: i32, n: int) -> int;\n'
        '}\n'
        'import from "libSystem.B.dylib" {\n'
        '    def memset(s: int, c: i32, n: int) -> int;\n'
        '}\n'
        'def clear(buf: int, fill: int) -> int {\n'
        '    memset(buf, 0, 1);\n'
        '    memset(buf, i32(fill), 4);\n'
        '    return memset(buf, -1, 2);\n'
        '}\n'
    );
    assert check(src) == [] , check(src);
    assert check(src, "native") == [] , check(src, "native");
}

test "sized fields and Callable members of an extern struct are typed on every lane" {
    src = (
        'import from m {\n'
        '    obj Api { has depth: u8 = 0, get_error: Callable[[int, int], i32] = 0, free: Callable[[int], None] = 0; }\n'
        '}\n'
        'def drive(api: Api, h: int, n: int) -> int {\n'
        '    rc = api.get_error(h, h);\n'
        '    if rc != 0 {\n'
        '        api.depth = n;\n'
        '    }\n'
        '    api.depth = u8(n);\n'
        '    api.free(h);\n'
        '    d: int = api.depth;\n'
        '    return d + rc;\n'
        '}\n'
    );
    expected = [("E1127", 7, 21)];
    assert fw_only(check(src)) == expected , check(src);
    assert fw_only(check(src, "native")) == expected , check(src, "native");
}

test "a foreign int return keeps its declared scalar for the lattice on every lane" {
    src = (
        'import from "libc.so.6" {\n'
        '    def strlen(s: str) -> int;\n'
        '    def take(n: i32) -> i32;\n'
        '}\n'
        'def f(title: str) -> int {\n'
        '    take(strlen(title));\n'
        '    w: i32 = strlen(title);\n'
        '    n: int = strlen(title);\n'
        '    if strlen(title) == 0 {\n'
        '        return n;\n'
        '    }\n'
        '    return take(i32(strlen(title)));\n'
        '}\n'
    );
    expected = [("E1127", 6, 10), ("E1127", 7, 14)];
    assert fw_only(check(src)) == expected , check(src);
    assert fw_only(check(src, "native")) == expected , check(src, "native");
}

test "a Callable member of an extern struct is enforced at construction" {
    src = (
        'import from m {\n'
        '    obj VT { has size: int = 0, on_event: Callable[[i32, i32], i32] = 0; }\n'
        '}\n'
        'def cb_int(a: int, b: int) -> int {\n'
        '    return a + b;\n'
        '}\n'
        'def cb_i32(a: i32, b: i32) -> i32 {\n'
        '    return a + b;\n'
        '}\n'
        'def build -> int {\n'
        '    bad = VT(size=1, on_event=cb_int);\n'
        '    good = VT(size=1, on_event=cb_i32);\n'
        '    return 0;\n'
        '}\n'
    );
    diags = [
        d
        for d in check(src)
        if d[0] in ("E1053", "E1127")
    ];
    assert len(diags) == 1 and diags[0][1] == 11 , check(src);
    diags_na = [
        d
        for d in check(src, "native")
        if d[0] in ("E1053", "E1127")
    ];
    assert len(diags_na) == 1 and diags_na[0][1] == 11 , check(src, "native");
}
