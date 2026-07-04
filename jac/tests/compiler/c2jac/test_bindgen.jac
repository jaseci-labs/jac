"""cbindgen output tests (jaseci #7145, Leg 2).

`jac cbindgen` now builds real `Import.clib_decls` UniIR and unparses it, rather
than concatenating `.na.jac` text. So these tests assert two things: the FFI type
mapping and symbol filtering are correct (structural substring checks), and the
generated bindings are genuine nacompile input -- every fixture's output compiles
through the native front-end, and the final two drive a real extern call against
libm through the JIT (the #7055 acceptance loop).
"""

import os;
import ctypes;
import tempfile;
import from tests.compiler.c2jac.support { read_fixture }
import from jaclang.compiler.c2jac.bindgen { bindings_from_source }
import from jaclang.jac0core.program { JacProgram }

def _bind(
    name: str, lib: str, allow: list | None = None, block: list | None = None
) -> tuple {
    # (jac_str, report) for a fixture header under fixtures/bindgen/.
    return bindings_from_source(
        read_fixture(name), name.rsplit("/", 1)[-1], lib, allow=allow, block=block
    );
}

def _compile_bindings(src: str) -> tuple {
    # Write generated `.na.jac` (optionally with a consumer) to a temp file and
    # run it through the native compiler. Returns (prog, ir).
    out_dir = tempfile.mkdtemp();
    path = os.path.join(out_dir, "bind_probe.na.jac");
    with open(path, "w") as f {
        f.write(src);
    }
    prog = JacProgram();
    ir = prog.compile(file_path=path);
    return (prog, ir);
}

def _assert_compiles(out: str) {
    # The generated bindings must be valid nacompile input, not just well-formed
    # text -- the whole point of building IR instead of concatenating strings.
    (prog, _ir) = _compile_bindings(out);
    assert not prog.errors_had , f"generated bindings do not compile: {[
        str(e) for e in prog.errors_had
    ]}";
}

# ---------------------------------------------------------------------------- #
# Phase 0 — extern function prototypes                                         #
# ---------------------------------------------------------------------------- #
test "Phase 0 binds every primitive-width prototype with the right FFI types" {
    (out, rep) = _bind("bindgen/test.h", "tk");
    assert "import from \"tk\" {" in out , out;
    assert "def tk_add(a: i32, b: i32) -> i32;" in out , out;
    assert "def tk_scale(x: f64, k: f32) -> f64;" in out , out;
    assert "def tk_clamp(lo: i16, hi: i16, v: i32) -> i16;" in out , out;
    assert rep.functions == 7 , f"expected 7 functions, got {rep.functions}";
    _assert_compiles(out);
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
    # varargs are skipped by native FFI, so `rest` carries a placeholder `int`
    # annotation purely to satisfy the type checker.
    assert "def tk_logf(fmt: str, *rest: int) -> i32;" in out , out;
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
    _assert_compiles(out);
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
    _assert_compiles(out);
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
# Phase 3 — struct layout bindings                                             #
# ---------------------------------------------------------------------------- #
test "Phase 3 emits obj for a plain named struct with int fields" {
    (out, rep) = _bind("bindgen/structs.h", "geo");
    # struct fields carry no default (matching the direct-lift convention).
    assert "obj Point {" in out , out;
    assert "has x: i32;" in out , out;
    assert "has y: i32;" in out , out;
    _assert_compiles(out);
}

test "Phase 3 emits obj for a typedef'd anonymous struct with float fields" {
    (out, rep) = _bind("bindgen/structs.h", "geo");
    assert "obj Color {" in out , out;
    assert "has r: f32;" in out , out;
    assert "has g: f32;" in out , out;
    assert "has b: f32;" in out , out;
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

# ---------------------------------------------------------------------------- #
# Extern variables are not FFI-bindable                                        #
# ---------------------------------------------------------------------------- #
test "extern file-scope variables are not emitted as bindings" {
    # Native FFI (targets/foreign.jac) only consumes Ability (functions) and
    # Archetype (structs) from clib_decls -- there is no representable form for
    # an extern global, so cbindgen no longer emits one.
    (out, rep) = _bind("bindgen/externs.h", "ex");
    assert "last_err" not in out , out;
    assert "threshold" not in out , out;
    assert rep.externs == 0 , f"externs are unsupported, got {rep.externs}";
}

# ---------------------------------------------------------------------------- #
# #7055 acceptance — a generated binding drives a real extern call against      #
# libm through the JIT.                                                         #
# ---------------------------------------------------------------------------- #
def _libm -> str | None {
    # First present libm on this host, or None (non-Linux CI: exec tests skip).
    for cand in [
        "/usr/lib/libm.so.6",
        "/lib/x86_64-linux-gnu/libm.so.6",
        "/usr/lib/x86_64-linux-gnu/libm.so.6"
    ] {
        if os.path.exists(cand) {
            return cand;
        }
    }
    return None;
}

test "generated FFI bindings compile through nacompile (#7055 acceptance)" {
    libm = _libm();
    if libm is None {
        return;
    }
    (out, _rep) = bindings_from_source("double sqrt(double x);\n", "libm.h", libm);
    assert f'import from "{libm}"' in out , out;
    (prog, ir) = _compile_bindings(out);
    assert not prog.errors_had , f"nacompile rejected generated bindings: {[
        str(e) for e in prog.errors_had
    ]}";
    assert 'declare double @"sqrt"' in str(ir.gen.llvm_ir) , "sqrt not declared extern in IR";
}

test "a generated binding makes a real extern call through the JIT (#7055)" {
    libm = _libm();
    if libm is None {
        return;
    }
    (out, _rep) = bindings_from_source("double sqrt(double x);\n", "libm.h", libm);
    consumer = out + "\ndef:pub jac_call_sqrt(x: f64) -> f64 {\n    return sqrt(x);\n}\n\nwith entry {}\n";
    (prog, ir) = _compile_bindings(consumer);
    assert not prog.errors_had , f"nacompile errors: {[
        str(e) for e in prog.errors_had
    ]}";
    eng = ir.gen.native_engine;
    if eng is None {
        return;
    }
    addr = eng.get_function_address("jac_call_sqrt");
    assert addr != 0 , "jac_call_sqrt not linked into the JIT engine";
    fn = ctypes.CFUNCTYPE(ctypes.c_double, ctypes.c_double)(addr);
    got = fn(9.0);
    assert got == 3.0 , f"expected sqrt(9.0)==3.0 through the generated FFI binding, got {got}";
}
