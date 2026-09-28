"""C pointer interop across every memory profile and the Python backend.

A foreign struct (a fielded `obj` in a clib import block) is C-layout plain
data with nested structs embedded by value. A `&T` / `&mut T` clib parameter
lends C the address of Jac storage for the call, `ptr[T]` holds a C address,
`p.view(n)` is a bounds-checked view of C memory, an opaque C type is handled
only by address, and `Pinned[T]` keeps a payload's address stable while C
holds on to it.

`fixtures/clib_pointers.c` is the reference library: out-parameter structs,
in-place mutation, scalar out-parameters, a returned byte buffer and struct
array, an opaque handle created and destroyed through out-parameters, and
pointers the library retains between calls. The fixture program prints the
same thing under nogc, rc and managed native builds and on the Python
backend. The checker tests pin the diagnostics that keep the surface sound.
"""

import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support {
    assert_native_identity,
    compile_native_ir,
    native_build,
    native_run
}
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURES: Path = Path(__file__).resolve().parent / "fixtures";

"""Compile the reference C library into `directory`; return its path."""
def build_reference_library(directory: str) -> str {
    cc = shutil.which("cc") or shutil.which("gcc");
    if not cc {
        testskip("no C compiler available for the reference library");
    }
    library = str(Path(directory) / "libclib_pointers.so");
    built = subprocess.run(
        [
            cc,
            "-shared",
            "-fPIC",
            "-O1",
            str(FIXTURES / "clib_pointers.c"),
            "-o",
            library
        ],
        capture_output=True,
        text=True,
        timeout=60
    );
    assert built.returncode == 0 , built.stderr;
    return library;
}

"""Write `code` into `directory` with the reference library's path filled in."""
def stage_source(directory: str, code: str, name: str = "probe.jac") -> str {
    library = build_reference_library(directory);
    path = str(Path(directory) / name);
    Path(path).write_text(code.replace("CLIB_POINTERS_LIBRARY", library));
    return path;
}

"""Type-check `code` against the reference library; return its error codes."""
def checker_codes(code: str) -> list[str] {
    with tempfile.TemporaryDirectory() as directory {
        path = stage_source(directory, code);
        prog = JacProgram();
        prog.compile(file_path=path, options=CompileOptions(no_cgen=True));
        codes: list[str] = [];
        for alert in list(prog.errors_had) {
            if alert.code is not None {
                codes.append(alert.code.code);
            }
        }
        return codes;
    }
}

glob DECLS: str = '''import from "CLIB_POINTERS_LIBRARY" {
    obj CpVec3 { has x: f32, y: f32, z: f32; }
    obj CpCamera { has position: CpVec3, target: CpVec3, fovy: f32, mode: i32; }
    obj CpDb;
    obj CpBatch { has draws: i32, last: i32, vbo: ptr, tint: CpVec3; }
    def cp_camera_init(cam: &mut CpCamera, fovy: f32) -> None;
    def cp_points_new(n: i32) -> ptr[CpVec3];
    def cp_find(key: i32) -> ptr[CpVec3];
    def cp_db_open(name: str, out: &mut ptr[CpDb]) -> i32;
    def cp_batch_set_active(batch: &mut Pinned[CpBatch] | None) -> None;
}
''';

test "C pointer interop agrees across memory profiles and the Python backend" {
    source = (FIXTURES / "clib_pointers.jac").read_text();
    with tempfile.TemporaryDirectory() as directory {
        out = assert_native_identity(
            stage_source(directory, source, "clib_pointers.jac")
        );
    }
    expected = [
        "init 2.0 4.0 45.0 1",
        "orbit 1.5 -1.5 2",
        "span 9.0",
        "by value 54.5",
        "returned 4.0 30.0",
        "copy 0.0 100.0",
        "store 0.0 2.0 4.0",
        "in place 5.0 -2.5 3.5",
        "window 1280 720",
        "bump 42 2.5 10 True",
        "buffer 6 0 15 15",
        "buffer sum 240",
        "buffer index PtrView index out of range",
        "point copy 1.0 50.0",
        "point sum 69.0",
        "sorted 50.0 2.0 1.0 0.0",
        "find True False 9.0",
        "equal True False True",
        "truth True False",
        "cast 7.0",
        "null view cannot view elements of a null pointer",
        "empty view 0",
        "open 0 False",
        "put 2 12",
        "session True True 1",
        "open empty 1 True",
        "batch 2 9 1.0",
        "draw 101 101",
        "inactive False -1",
        "counter 21",
        "counter 15",
        "optional none 0",
        "optional out 1 7",
        "renderer 2 8",
        "list 3 4.0",
        "step 2.0 2.0",
        "distance 2 -2",
        "aug True 2.0",
        "bytes 24",
        "address True 24",
        "void step True",
        "byte 15",
        "global 7 True",
        "global write 12",
        "global object True 2.0",
        "global place 9.0",
        "global address 40",
        "global flag False",
        "defined 18 6 5.0",
        "defined scalar 100 5",
        "defined array 16.0 10.0 24"
    ];
    lines = out.splitlines();
    for line in expected {
        assert line in lines , f"missing {line!r} in:\n{out}";
    }
}

test "foreign structs lay nested structs out inline and lend their address" {
    code = DECLS
        + '''
def run -> f32 {
    cam = CpCamera();
    cp_camera_init(&mut cam, f32(1.0));
    return cam.position.y;
}
''';
    with tempfile.TemporaryDirectory() as directory {
        stage_source(directory, code);
        text = str(compile_native_ir("probe.jac", fixture_dir=directory).gen.llvm_ir);
    }
    assert '%"CpCamera" = type {%"CpVec3", %"CpVec3", float, i32}' in text;
    assert '%"CpBatch" = type {i32, i32, i64, %"CpVec3"}' in text;
    assert 'declare void @"cp_camera_init"(i8* %"cam", float %"fovy")' in text;
    assert 'declare i32 @"cp_db_open"(i8* %"name", i8* %"out")' in text;
    assert 'declare i8* @"cp_find"(i32 %"key")' in text;
}

test "foreign struct fields must be C plain data" {
    code = '''import from "CLIB_POINTERS_LIBRARY" {
    obj CpVec3 { has x: f32, y: f32, z: f32; }
    obj Named { has name: str; }
    obj Listed { has items: list[int]; }
    obj Fine { has v: CpVec3, p: ptr[CpVec3], q: ptr, n: int, ok: bool, f: float; }
    obj Loop { has other: Loop2; }
    obj Loop2 { has back: Loop; }
}
''';
    assert checker_codes(code) == ["E1150", "E1150", "E1150", "E1150"];
}

test "an opaque C type is only handled by address" {
    code = '''import from "CLIB_POINTERS_LIBRARY" {
    obj CpDb;
    obj Holder { has db: CpDb; }
    def by_value(db: CpDb) -> CpDb;
    def by_address(db: ptr[CpDb]) -> ptr[CpDb];
}
obj Owner { has db: ptr[CpDb] = ptr[CpDb](); }
def local_use(db: CpDb) {}
with entry {
    made = CpDb();
}
''';
    assert checker_codes(code) == ["E1151", "E1151", "E1151", "E1151", "E1151"];
}

test "pin, view and C borrow parameters need C plain data" {
    code = '''import from "CLIB_POINTERS_LIBRARY" {
    obj CpDb;
    def takes_str(s: &mut str) -> None;
    def any_address -> ptr;
}
obj Thing { has n: int = 0; }
with entry {
    held = pin(Thing());
    opaque = ptr[CpDb](any_address()).view(2);
}
''';
    assert checker_codes(code) == ["E1152", "E1152", "E1152"];
}

test "a C memory view cannot outlive its scope" {
    code = DECLS
        + '''
obj Keeper { has view: PtrView[CpVec3] | None = None; }
def escape(p: ptr[CpVec3]) -> PtrView[CpVec3] {
    return p.view(1);
}
def store(p: ptr[CpVec3], k: Keeper) {
    v = p.view(1);
    k.view = v;
    kept = [v];
    print(len(v), len(kept));
}
def local_use(p: ptr[CpVec3]) -> f32 {
    v = p.view(2);
    return v[0].x + v[1].x;
}
''';
    assert checker_codes(code) == ["E1315", "E1315", "E1315", "E1315"];
}

test "a Pinned parameter accepts only a pinned value or None" {
    code = DECLS
        + '''
with entry {
    pinned = pin(CpBatch());
    cp_batch_set_active(&mut pinned);
    cp_batch_set_active(None);
    plain = CpBatch();
    cp_batch_set_active(&mut plain);
}
''';
    assert checker_codes(code) == ["E1053"];
}

test "pointer types match exactly and a bare ptr narrows only by cast" {
    code = DECLS
        + '''
def widen(p: ptr[CpVec3]) -> ptr { return p; }
def narrow(p: ptr) -> ptr[CpVec3] { return p; }
def cast(p: ptr) -> ptr[CpVec3] { return ptr[CpVec3](p); }
def mismatch(p: ptr[CpVec3]) -> ptr[CpDb] { return p; }
def scalar(p: ptr[u8]) -> ptr[i8] { return p; }
''';
    assert checker_codes(code) == ["E1002", "E1002", "E1002"];
}

test "C data symbols are declared without a value and C objects are used by address" {
    code = DECLS
        + '''
import from "CLIB_POINTERS_LIBRARY" {
    glob cp_global_count: i32 = cp_global_read();
    glob cp_global_name: str;
    glob cp_global_origin: CpVec3;
    glob cp_global_db: CpDb;
    glob cp_defined_db: CpDb = cp_global_db;
    def cp_global_read -> i32;
}
def use_object -> CpVec3 { return cp_global_origin; }
def use_opaque -> ptr[CpDb] { return addressof(cp_global_db); }
def not_symbol(v: i32) -> ptr[i32] { return addressof(v); }
def computed(name: str) -> ptr[u8] { return ptr[u8](name); }
def wide -> ptr[i32] { return ptr[i32]("text"); }
''';
    assert checker_codes(code)
        == ["E1155", "E1153", "E1153", "E1153", "E1154", "E1156", "E1156"];
}

test "C data symbols imported from another module stay C variables" {
    decls = '''import from "CLIB_POINTERS_LIBRARY" {
    obj CpVec3 { has x: f32, y: f32, z: f32; }
    def cp_global_read -> i32;
    glob cp_global_count: i32, cp_global_origin: CpVec3, cp_global_origin_ref: ptr[CpVec3];
}
''';
    user = '''import from cdecls {
    cp_global_count, cp_global_origin, cp_global_origin_ref, cp_global_read
}
with entry {
    cp_global_count += i32(5);
    print("imported", cp_global_read(), cp_global_count);
    print("imported object", addressof(cp_global_origin) == cp_global_origin_ref);
}
''';
    with tempfile.TemporaryDirectory() as directory {
        stage_source(directory, decls, "cdecls.jac");
        out = assert_native_identity(stage_source(directory, user, "user.jac"));
    }
    assert "imported 12 12" in out.splitlines() , out;
    assert "imported object True" in out.splitlines() , out;
}

test "C variadic arguments take the C default promotions on every path" {
    code = '''import from c {
    def printf(fmt: str, *args: any) -> i32;
    def fflush(stream: i64) -> i32;
    def snprintf(buf: ptr[u8], n: i64, fmt: ptr[u8], *args: any) -> i32;
    def malloc(n: i64) -> ptr[u8];
    def free(p: ptr[u8]) -> None;
}
with entry {
    printf("plain %d|%lld|%.1f|%u|%d|%s\\n", i32(-7), i64(1) << 40, f32(1.5), u8(200), i8(-3), "jac");
    fflush(0);
    buf = malloc(128);
    n = snprintf(
        buf, 128, ptr[u8]("%d|%lld|%s|%.2f|%.1f|%u|%d|%s"),
        i32(-7), i64(1) << 40, ptr[u8]("lit"), 2.5, f32(1.5), u8(200), i8(-3), "jac"
    );
    view = buf.view(int(n));
    print("varargs", "".join([chr(int(view[i])) for i in range(int(n))]));
    free(buf);
}
''';
    with tempfile.TemporaryDirectory() as directory {
        path = str(Path(directory) / "varargs.jac");
        Path(path).write_text(code);
        out = assert_native_identity(path);
    }
    assert "plain -7|1099511627776|1.5|200|-3|jac" in out.splitlines() , out;
    assert "varargs -7|1099511627776|lit|2.50|1.5|200|-3|jac" in out.splitlines() , out;
}

test "a C variadic function Jac defines reads each argument by its C type" {
    code = '''import from c {
    def vsnprintf(buf: ptr[u8], n: i64, fmt: ptr[u8], ap: VaList) -> i32;
    def malloc(n: i64) -> ptr[u8];
    def free(p: ptr[u8]) -> None;
}
def sum_mixed(count: i32, *args: VaList) -> f64 {
    total = 0.0;
    for i in range(int(count)) {
        if i % 2 == 0 {
            total += float(args.arg(i64));
        } else {
            total += args.arg(f64);
        }
    }
    return total;
}
def narrow(count: i32, *args: VaList) -> str {
    out = "";
    for i in range(int(count)) {
        out += f"{args.arg(i8)},";
    }
    return out + f"{args.arg(bool)}";
}
def format_into(buf: ptr[u8], n: i64, fmt: ptr[u8], *args: VaList) -> i32 {
    return vsnprintf(buf, n, fmt, args);
}
with entry {
    print("mixed", sum_mixed(i32(4), i64(1), 2.5, i64(3), 4.25));
    print(
        "spill",
        sum_mixed(
            i32(20), i64(1), 1.5, i64(2), 2.5, i64(3), 3.5, i64(4), 4.5, i64(5), 5.5,
            i64(6), 6.5, i64(7), 7.5, i64(8), 8.5, i64(9), 9.5, i64(10), 10.5
        )
    );
    print("narrow", narrow(i32(3), i8(-1), i8(2), i8(-3), True));
    buf = malloc(64);
    written = format_into(buf, 64, ptr[u8]("%s=%d/%.2f"), "key", i32(-5), 1.5);
    view = buf.view(int(written));
    print("forward", "".join([chr(int(view[i])) for i in range(int(written))]));
    free(buf);
}
''';
    with tempfile.TemporaryDirectory() as directory {
        path = str(Path(directory) / "variadic_def.jac");
        Path(path).write_text(code);
        out = assert_native_identity(path);
    }
    lines = out.splitlines();
    for line in [
        "mixed 10.75",
        "spill 115.0",
        "narrow -1,2,-3,True",
        "forward key=-5/1.50"
    ] {
        assert line in lines , f"missing {line!r} in:\n{out}";
    }
}

test "C variadic functions reject keyword parameters and non-C arguments" {
    code = DECLS
        + '''
def keyed(fmt: ptr[u8], *args: VaList, flag: bool = False) -> None {}
def plain(fmt: ptr[u8], *args: VaList) -> None {}
def call_it -> None { plain(ptr[u8](), [1, 2]); }
''';
    assert checker_codes(code) == ["E1157", "E1157"];
}

test "C data definitions use Final constants and structs another module declares" {
    decls = '''import from "CLIB_POINTERS_LIBRARY" {
    obj CpVec3 { has x: f32, y: f32, z: f32; }
    obj CpRecipe {
        has count: i32, scale: Callable[[i32], i32], label: ptr[u8], origin: ptr[CpVec3];
    }
    def cp_recipe_run(r: ptr[CpRecipe], v: i32) -> i32;
    def cp_label_len(s: ptr[u8]) -> i32;
}
glob CP_COUNT: Final[i32] = 6, CP_LIMIT: Final[i64] = (1 << 40) + 2;
''';
    user = '''import from cdecls { CP_COUNT, CP_LIMIT, CpRecipe, CpVec3, cp_label_len, cp_recipe_run }
import from "CLIB_POINTERS_LIBRARY" {
    glob user_origin: CpVec3 = CpVec3(x=f32(1.0), y=f32(2.0), z=f32(3.0)),
         user_recipe: CpRecipe = CpRecipe(
             count=CP_COUNT | 1,
             scale=double,
             label=ptr[u8]("user"),
             origin=addressof(user_origin)
         ),
         user_limit: i64 = CP_LIMIT;
}
def double(v: i32) -> i32 {
    return v * i32(2);
}
with entry {
    recipe = addressof(user_recipe);
    print(
        "final",
        cp_recipe_run(recipe, i32(5)),
        cp_label_len(recipe.view(1)[0].label),
        recipe.view(1)[0].origin.view(1)[0].z,
        user_limit
    );
}
''';
    with tempfile.TemporaryDirectory() as directory {
        stage_source(directory, decls, "cdecls.jac");
        out = assert_native_identity(stage_source(directory, user, "user.jac"));
    }
    assert "final 17 4 3.0 1099511627778" in out.splitlines() , out;
}

test "only Final globs are C constants" {
    code = DECLS
        + '''
glob plain_count: i32 = 3;
glob fixed_count: Final[i32] = 3;
import from "CLIB_POINTERS_LIBRARY" {
    glob cp_plain: i32 = plain_count, cp_fixed: i32 = fixed_count + 1;
}
''';
    assert checker_codes(code) == ["E1155"];
}

glob C_DEFINITION_LIBRARY: str = '''#include <stdint.h>
typedef struct { int32_t a; double b; } CdPair;
typedef struct { int64_t a, b, c; } CdTriple;
double cd_call_pair(CdPair (*make)(int32_t, double), int32_t a, double b) {
    CdPair p = make(a, b);
    return p.a + p.b;
}
int64_t cd_call_triple(CdTriple (*make)(int64_t), int64_t base) {
    CdTriple t = make(base);
    return t.a + t.b + t.c;
}
int64_t cd_call_sum(int64_t (*sum)(CdTriple, int32_t), int64_t base) {
    CdTriple t = {base, base * 2, base * 3};
    return sum(t, 100);
}
''',
     C_DEFINITION_PROGRAM: str = '''import from "CD_LIBRARY" {
    obj CdPair { has a: i32, b: f64; }
    obj CdTriple { has a: i64, b: i64, c: i64; }
    def cd_call_pair(make: Callable[[i32, f64], CdPair], a: i32, b: f64) -> f64;
    def cd_call_triple(make: Callable[[i64], CdTriple], base: i64) -> i64;
    def cd_call_sum(sum: Callable[[CdTriple, i32], i64], base: i64) -> i64;
    def jac_make_pair(a: i32, b: f64) -> CdPair {
        return CdPair(a=a, b=b * 2.0);
    }
    def jac_make_triple(base: i64) -> CdTriple {
        return CdTriple(a=base, b=base + 1, c=base + 2);
    }
    def jac_sum_triple(t: CdTriple, extra: i32) -> i64 {
        return t.a + t.b + t.c + i64(extra);
    }
}
with entry {
    print("pair", cd_call_pair(jac_make_pair, i32(3), 1.25));
    print("triple", cd_call_triple(jac_make_triple, 10));
    print("sum", cd_call_sum(jac_sum_triple, 5));
    print("direct", jac_sum_triple(CdTriple(a=1, b=2, c=3), i32(4)));
}
''';

test "a function a C library block defines has its C name and the C ABI" {
    cc = shutil.which("cc") or shutil.which("gcc");
    if not cc {
        testskip("no C compiler available for the reference library");
    }
    with tempfile.TemporaryDirectory() as directory {
        library = str(Path(directory) / "libcdef.so");
        source = Path(directory) / "cdef.c";
        source.write_text(C_DEFINITION_LIBRARY);
        built = subprocess.run(
            [cc, "-shared", "-fPIC", "-O1", str(source), "-o", library],
            capture_output=True,
            text=True,
            timeout=60
        );
        assert built.returncode == 0 , built.stderr;
        program = Path(directory) / "cdef.jac";
        program.write_text(C_DEFINITION_PROGRAM.replace("CD_LIBRARY", library));
        for memory in ("nogc", "rc", "managed") {
            binary = str(Path(directory) / f"cdef.{memory}");
            native_build(str(program), binary, memory=memory);
            lines = native_run(binary).splitlines();
            for expected in ["pair 5.5", "triple 33", "sum 130", "direct 10"] {
                assert expected in lines , f"{memory}: missing {expected!r} in {lines}";
            }
        }
    }
}

test "C function definitions agree across backends and C variadic definitions keep their C name" {
    code = '''import from c {
    def abs(v: i32) -> i32;
    def jac_twice(v: i32) -> i32 {
        return abs(v) * i32(2);
    }
    def jac_sum_ints(count: i32, *args: VaList) -> i64 {
        total: i64 = 0;
        for i in range(int(count)) {
            total += args.arg(i64);
        }
        return total;
    }
}
with entry {
    print("twice", jac_twice(i32(-21)));
    print("variadic", jac_sum_ints(i32(3), i64(1), i64(20), i64(300)));
}
''';
    with tempfile.TemporaryDirectory() as directory {
        path = str(Path(directory) / "cdef_scalar.jac");
        Path(path).write_text(code);
        out = assert_native_identity(path);
    }
    assert "twice 42" in out.splitlines() , out;
    assert "variadic 321" in out.splitlines() , out;
}

test "C function definitions take and return C data" {
    code = DECLS
        + '''
import from "CLIB_POINTERS_LIBRARY" {
    def takes_text(s: str) -> i32 { return i32(0); }
    def borrows(v: &mut i32) -> None { print(v); }
    def packs(*values: int) -> None { print(values); }
    def variadic_struct(v: CpVec3, *args: VaList) -> None { print(v.x); }
    def returns_list -> list[int] { return []; }
}
''';
    assert checker_codes(code) == ["E1158", "E1158", "E1158", "E1158", "E1158"];
}
