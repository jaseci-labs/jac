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
import from tests.support { assert_native_identity, compile_native_ir }
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
        "renderer 2 8",
        "list 3 4.0"
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
