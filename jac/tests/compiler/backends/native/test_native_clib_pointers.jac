"""C pointer interop across every memory profile and the Python backend.

A foreign struct (a fielded `obj` in a clib import block) is C-layout plain
data with nested structs embedded by value. A `&T` / `&mut T` clib parameter
lends C the address of Jac storage for the call, as `&mut x` passed to a C
function's `ptr[T]` parameter does, `ptr[T]` holds a C address,
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
        "order True True True False",
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

test "pointers order by unsigned address across memory profiles and the Python backend" {
    code = '''import from c {
    glob order_cells: list[i32] = [i32(1), i32(2), i32(3)];
}
with entry {
    first = addressof(order_cells);
    last = first + 2;
    print("lt", first < last, last < first, first < first);
    print("le", first <= last, last <= first, first <= first);
    print("gt", last > first, first > last, last > last);
    print("ge", last >= first, first >= last, last >= last);
    print("chain", first < first + 1 < last, first < last < first);
    print("bare", ptr(first) < ptr(last), ptr(first) < last, last > ptr(first));
    high = ptr[u8](0xFFFFFFFFFFFFFFF0);
    low = ptr[u8](16);
    print("unsigned", high > low, low < high, high >= low, low <= high);
}
''';
    with tempfile.TemporaryDirectory() as directory {
        path = Path(directory) / "ordering.jac";
        path.write_text(code);
        out = assert_native_identity(str(path));
    }
    lines = out.splitlines();
    for expected in [
        "lt True False False",
        "le True False True",
        "gt True False False",
        "ge True False True",
        "chain True False",
        "bare True True True",
        "unsigned True True True True"
    ] {
        assert expected in lines , f"missing {expected!r} in:\n{out}";
    }
}

test "pointer ordering needs one pointee type" {
    code = DECLS
        + '''
def same(p: ptr[CpVec3], q: ptr[CpVec3]) -> bool { return p < q; }
def widened(p: ptr[CpVec3], q: ptr) -> bool { return p <= q and q >= p; }
def mismatch(p: ptr[CpVec3], q: ptr[CpDb]) -> bool { return p > q; }
def scalar(p: ptr[u8], q: ptr[i8]) -> bool { return p >= q; }
def integer(p: ptr[u8]) -> bool { return p < 16; }
''';
    assert checker_codes(code) == ["E1110", "E1110", "E1110"];
}

test "a function rebinds a C data glob of another module in place" {
    holder = '''import from c {
    obj GbRec {
        has a: i32;
    }
    glob:priv gb_kept: ptr[GbRec] = ptr[GbRec]();
    glob gb_count: i32 = i32(0);
    glob gb_recs: list[GbRec] = [GbRec(a=i32(5)), GbRec(a=i32(6))];
}
glob gb_calls: int = 0;

def keep(p: ptr[GbRec]) {
    gb_kept = p;
    gb_count += i32(1);
    gb_calls = gb_calls + 1;
}

def kept_value -> i32 {
    return gb_kept.view(1)[0].a;
}

def calls -> int {
    return gb_calls;
}
''';
    main = '''import from holder { calls, gb_count, gb_recs, keep, kept_value }
with entry {
    keep(addressof(gb_recs));
    print("first", kept_value(), gb_count, calls());
    keep(addressof(gb_recs) + 1);
    print("second", kept_value(), gb_count, calls());
}
''';
    with tempfile.TemporaryDirectory() as directory {
        (Path(directory) / "holder.jac").write_text(holder);
        path = Path(directory) / "rebind.jac";
        path.write_text(main);
        out = assert_native_identity(str(path));
    }
    lines = out.splitlines();
    assert "first 5 1 1" in lines , out;
    assert "second 6 2 2" in lines , out;
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

test "a foreign struct embeds one another module embeds from a third" {
    inner = '''import from c {
    obj NsInner {
        has x: i64, y: i64, scale: Callable[[i64], i64];
    }
}
''';
    middle = '''import from nsinner { NsInner }
import from c {
    obj NsMiddle {
        has inner: NsInner, z: i64;
    }
}
''';
    outer = '''import from nsmiddle { NsMiddle }
import from nsinner { NsInner }
import from c {
    obj NsOuter {
        has middle: NsMiddle, w: i64;
    }
    glob ns_outer: NsOuter = NsOuter(
        middle=NsMiddle(inner=NsInner(x=i64(1), y=i64(2), scale=triple), z=i64(3)),
        w=i64(4)
    );
}

def triple(v: i64) -> i64 {
    return v * i64(3);
}

def read(p: ptr[NsMiddle]) -> i64 {
    return p.view(1)[0].z + p.view(1)[0].inner.y;
}

with entry {
    record = addressof(ns_outer).view(1);
    print("nested", record[0].w, record[0].middle.z, record[0].middle.inner.x);
    print("through", read(ptr[NsMiddle](addressof(ns_outer))));
    print("callback", record[0].middle.inner.scale(i64(5)));
    record[0].middle.inner.y = i64(40);
    print("write", record[0].middle.inner.y);
}
''';
    with tempfile.TemporaryDirectory() as directory {
        Path(directory, "nsinner.jac").write_text(inner);
        Path(directory, "nsmiddle.jac").write_text(middle);
        path = Path(directory, "nsouter.jac");
        path.write_text(outer);
        out = assert_native_identity(str(path));
    }
    lines = out.splitlines();
    for expected in ["nested 4 3 1", "through 5", "callback 15", "write 40"] {
        assert expected in lines , f"missing {expected!r} in:\n{out}";
    }
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

test "a bytes literal lays out a C integer array's little-endian elements" {
    code = '''import from "CLIB_POINTERS_LIBRARY" {
    glob bytes_u8: list[u8] = b"\\x01\\xff" b"A",
         bytes_u16: list[u16] = b"\\x34\\x12\\xff\\xff",
         bytes_i32: list[i32] = b"\\xfe\\xff\\xff\\xff\\x00\\x00\\x00\\x01";
}
with entry {
    small = addressof(bytes_u8).view(3);
    wide = addressof(bytes_u16).view(2);
    signed = addressof(bytes_i32).view(2);
    print("bytes", small[0], small[1], small[2], wide[0], wide[1], signed[0], signed[1]);
}
''';
    with tempfile.TemporaryDirectory() as directory {
        out = assert_native_identity(stage_source(directory, code));
    }
    assert "bytes 1 255 65 4660 65535 -2 16777216" in out.splitlines() , out;
}

test "a bytes literal initializes only a sized integer array of whole elements" {
    code = DECLS
        + '''
import from "CLIB_POINTERS_LIBRARY" {
    glob odd_u16: list[u16] = b"\\x01\\x02\\x03",
         reals: list[f64] = b"\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00";
}
''';
    assert checker_codes(code) == ["E1155", "E1155"];
}

test "a Jac function C calls runs outside the caller's open region" {
    code = '''import from "CLIB_POINTERS_LIBRARY" {
    obj CpVec3 { has x: f32, y: f32, z: f32; }
    obj CpRecipe {
        has count: i32, scale: Callable[[i32], i32], label: ptr[u8], origin: ptr[CpVec3];
    }
    def cp_recipe_run(r: ptr[CpRecipe], v: i32) -> i32;
    glob kept_recipe: CpRecipe = CpRecipe(count=i32(1), scale=remember);
}
obj Kept {
    has value: i32;

    def drop {}
}
def remember(v: i32) -> i32 {
    item = Kept(value=v);
    doubled = item.value * i32(2);
    print("callback on heap", region_of(item) is None);
    return doubled;
}
with entry {
    r: own Region = Region();
    in r {
        opened = Kept(value=i32(1));
        print("open", region_of(opened) is None);
        print("run", cp_recipe_run(addressof(kept_recipe), i32(20)));
    }
}
''';
    with tempfile.TemporaryDirectory() as directory {
        out = assert_native_identity(stage_source(directory, code));
    }
    lines = out.splitlines();
    assert "open False" in lines , out;
    assert "callback on heap True" in lines , out;
    assert "run 41" in lines , out;
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

glob FUNCTION_ADDRESS_LIBRARY: str = '''#include <stdint.h>
typedef struct { const char *name; void *code; int32_t arity; } FaEntry;
int64_t fa_call(const FaEntry *record, int64_t value) {
    if (record->arity == 1) return ((int64_t (*)(int64_t))record->code)(value);
    return ((int64_t (*)(int64_t, int64_t))record->code)(value, 3);
}
''',
     FUNCTION_ADDRESS_PROGRAM: str = '''import from "FA_LIBRARY" {
    obj FaEntry { has name: ptr[u8], code: ptr, arity: i32; }
    def fa_call(record: ptr[FaEntry], value: i64) -> i64;
    def fa_c_twice(value: i64) -> i64 {
        return value * 2;
    }
    glob fa_table: list[FaEntry] = [
             FaEntry(name=ptr[u8]("inc"), code=ptr(fa_inc), arity=1),
             FaEntry(name=ptr[u8]("scale"), code=ptr(fa_scale), arity=2),
             FaEntry(name=ptr[u8]("twice"), code=ptr(fa_c_twice), arity=1),
             FaEntry(name=ptr[u8](), code=ptr(), arity=0)
         ],
         fa_first: ptr[u8] = ptr[u8](addressof(fa_table));
}
def fa_inc(value: i64) -> i64 {
    return value + 1;
}
def fa_scale(value: i64, factor: i64) -> i64 {
    return value * factor;
}
with entry {
    table = addressof(fa_table);
    print("inc", fa_call(table, 41));
    print("scale", fa_call(table + 1, 5));
    print("twice", fa_call(table + 2, 21));
    print("end", (table + 3).view(1)[0].code.is_null());
    print("cast", int(fa_first) == int(table));
}
''';

test "a C data pointer field takes a named function's address" {
    cc = shutil.which("cc") or shutil.which("gcc");
    if not cc {
        testskip("no C compiler available for the reference library");
    }
    with tempfile.TemporaryDirectory() as directory {
        library = str(Path(directory) / "libfa.so");
        source = Path(directory) / "fa.c";
        source.write_text(FUNCTION_ADDRESS_LIBRARY);
        built = subprocess.run(
            [cc, "-shared", "-fPIC", "-O1", str(source), "-o", library],
            capture_output=True,
            text=True,
            timeout=60
        );
        assert built.returncode == 0 , built.stderr;
        program = Path(directory) / "fa.jac";
        program.write_text(FUNCTION_ADDRESS_PROGRAM.replace("FA_LIBRARY", library));
        for memory in ("nogc", "rc", "managed") {
            binary = str(Path(directory) / f"fa.{memory}");
            native_build(str(program), binary, memory=memory);
            lines = native_run(binary).splitlines();
            for expected in [
                "inc 42",
                "scale 15",
                "twice 42",
                "end True",
                "cast True"
            ] {
                assert expected in lines , f"{memory}: missing {expected!r} in {lines}";
            }
        }
    }
}

test "only a named function's address is a C constant pointer" {
    code = DECLS
        + '''
glob plain_address: int = 64;
import from "CLIB_POINTERS_LIBRARY" {
    obj FaSlot { has code: ptr; }
    glob fa_bad: FaSlot = FaSlot(code=ptr(plain_address));
}
''';
    assert checker_codes(code) == ["E1155"];
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

test "a borrowed C variadic argument passes the variable's address" {
    code = '''import from c {
    obj Opaque;
    def sscanf(text: str, fmt: str, *args: any) -> i32;
    def printf(fmt: str, *args: any) -> i32;
    def fflush(stream: i64) -> i32;
}

def scan_pointer -> ptr[Opaque] {
    q = ptr[Opaque]();
    sscanf("0x40", "%p", &mut q);
    return q;
}

with entry {
    x: i32 = 5;
    wide: i64 = 0;
    n = sscanf("42 7", "%d %lld", &mut x, &mut wide);
    printf("scan %d %d %lld\\n", n, x, wide);
    printf("pointer %lld\\n", int(scan_pointer()));
    fflush(0);
}
''';
    with tempfile.TemporaryDirectory() as directory {
        path = str(Path(directory) / "vaborrow.jac");
        Path(path).write_text(code);
        out = assert_native_identity(path);
    }
    assert "scan 2 42 7" in out.splitlines() , out;
    assert "pointer 64" in out.splitlines() , out;
}

test "ptr(f) is the address C calls a named function at" {
    code = '''import from "CLIB_POINTERS_LIBRARY" {
    obj CpErased { has name: ptr[u8], fn: ptr; }
    def cp_erased_call(e: ptr[CpErased], a: i64, b: i64) -> i64;
    def cp_address_call(fn: ptr, a: i64) -> i64;
    glob user_erased: list[CpErased] = [
             CpErased(name=ptr[u8]("sum"), fn=ptr(add)),
             CpErased(name=ptr[u8]("product"), fn=ptr(c_product))
         ];
    def c_product(a: i64, b: i64) -> i64 {
        return a * b;
    }
}
def add(a: i64, b: i64) -> i64 {
    return a + b;
}
def negate(a: i64) -> i64 {
    return -a;
}
with entry {
    table = addressof(user_erased);
    print(
        "erased",
        cp_erased_call(table, i64(3), i64(4)),
        cp_erased_call(table + 1, i64(3), i64(4)),
        cp_address_call(ptr(negate), i64(9))
    );
}
''';
    with tempfile.TemporaryDirectory() as directory {
        out = assert_native_identity(stage_source(directory, code, "erased.jac"));
    }
    assert "erased 7 12 -9" in out.splitlines() , out;
}

test "callback fields and ptr(f) take functions another module defines" {
    decls = '''import from "CLIB_POINTERS_LIBRARY" {
    obj CpErased { has name: ptr[u8], fn: ptr; }
    obj CpRecipe {
        has count: i32, scale: Callable[[i32], i32], label: ptr[u8], origin: ptr;
    }
    def cp_erased_call(e: ptr[CpErased], a: i64, b: i64) -> i64;
    def cp_recipe_run(r: ptr[CpRecipe], v: i32) -> i32;
}
def triple(v: i32) -> i32 {
    return v * i32(3);
}
def difference(a: i64, b: i64) -> i64 {
    return a - b;
}
''';
    user = '''import from cdecls {
    CpErased, CpRecipe, cp_erased_call, cp_recipe_run, difference, triple
}
import from "CLIB_POINTERS_LIBRARY" {
    glob user_entry: CpErased = CpErased(name=ptr[u8]("difference"), fn=ptr(difference)),
         user_recipe: CpRecipe = CpRecipe(count=i32(1), scale=triple);
}
with entry {
    print(
        "imported",
        cp_erased_call(addressof(user_entry), i64(10), i64(4)),
        cp_recipe_run(addressof(user_recipe), i32(5))
    );
}
''';
    with tempfile.TemporaryDirectory() as directory {
        stage_source(directory, decls, "cdecls.jac");
        out = assert_native_identity(stage_source(directory, user, "user.jac"));
    }
    assert "imported 6 16" in out.splitlines() , out;
}

test "int() of a callback field is the address C holds there" {
    code = '''import from "CLIB_POINTERS_LIBRARY" {
    obj CpRecipe {
        has count: i32, scale: Callable[[i32], i32], label: ptr[u8], origin: ptr;
    }
    def cp_call_i32(fn: ptr, v: i32) -> i32;
    glob user_recipe: CpRecipe = CpRecipe(count=i32(1), scale=triple),
         user_empty: CpRecipe = CpRecipe(count=i32(2));
}
def triple(v: i32) -> i32 {
    return v * i32(3);
}
with entry {
    recipe = addressof(user_recipe);
    held = int(recipe.view(1)[0].scale);
    print(
        "held",
        cp_call_i32(ptr(held), i32(5)),
        int(addressof(user_empty).view(1)[0].scale) == 0
    );
}
''';
    with tempfile.TemporaryDirectory() as directory {
        out = assert_native_identity(stage_source(directory, code, "held.jac"));
    }
    assert "held 15 True" in out.splitlines() , out;
}

glob LEND_LIBRARY: str = '''#include <stdint.h>
typedef struct { float x, y, z; } LnVec;
static LnVec ln_origin = {7.0f, 8.0f, 9.0f};
int32_t ln_set_i64(int64_t *out, int64_t v) { *out = v; return 1; }
void ln_read_i32(const int32_t *p, int64_t *out) { *out = (int64_t)*p * 10; }
void ln_scale(LnVec *v, float k) { v->x *= k; v->y *= k; v->z *= k; }
void ln_origin_of(LnVec **out) { *out = &ln_origin; }
''',
     LEND_DEFINITIONS: str = '''import from c {
    def ln_imported_bump(p: ptr[i64], amount: i64) {
        p.view(1)[0] = p.view(1)[0] + amount;
    }
}
''',
     LEND_PROGRAM: str = '''import from lend_defs { ln_imported_bump }
import from "LN_LIBRARY" {
    obj LnVec { has x: f32, y: f32, z: f32; }
    def ln_set_i64(out: ptr[i64], v: i64) -> i32;
    def ln_read_i32(p: ptr[i32], out: ptr[i64]) -> None;
    def ln_scale(v: ptr[LnVec], k: f32) -> None;
    def ln_origin_of(out: ptr[ptr[LnVec]]) -> None;
    def ln_double(p: ptr[i64]) {
        p.view(1)[0] = p.view(1)[0] * 2;
    }
    def ln_shift(v: ptr[LnVec]) {
        v.view(1)[0].x = v.view(1)[0].x + f32(1.0);
    }
}
obj Holder {
    has count: i64 = 3,
        vec: LnVec = LnVec(x=f32(1.0), y=f32(2.0), z=f32(3.0));
}
with entry {
    n: i64 = 0;
    print("set", ln_set_i64(&mut n, 41), n);
    ln_double(&mut n);
    print("double", n);
    ln_imported_bump(&mut n, 8);
    print("bump", n);
    small: i32 = 7;
    got: i64 = 0;
    ln_read_i32(&small, &mut got);
    print("read", got);
    v = LnVec(x=f32(1.0), y=f32(2.0), z=f32(3.0));
    ln_scale(&mut v, f32(2.0));
    ln_shift(&mut v);
    print("struct", v.x, v.y, v.z);
    origin = ptr[LnVec]();
    ln_origin_of(&mut origin);
    print("pointer", origin.view(1)[0].z);
    h = Holder();
    ln_set_i64(&mut h.count, 9);
    ln_double(&mut h.count);
    ln_scale(&mut h.vec, f32(3.0));
    print("field", h.count, h.vec.x);
}
''';

test "&mut x lends x's address to a C function's ptr[T] parameter" {
    cc = shutil.which("cc") or shutil.which("gcc");
    if not cc {
        testskip("no C compiler available for the reference library");
    }
    with tempfile.TemporaryDirectory() as directory {
        library = str(Path(directory) / "liblend.so");
        source = Path(directory) / "lend.c";
        source.write_text(LEND_LIBRARY);
        built = subprocess.run(
            [cc, "-shared", "-fPIC", "-O1", str(source), "-o", library],
            capture_output=True,
            text=True,
            timeout=60
        );
        assert built.returncode == 0 , built.stderr;
        (Path(directory) / "lend_defs.jac").write_text(LEND_DEFINITIONS);
        program = Path(directory) / "lend.jac";
        program.write_text(LEND_PROGRAM.replace("LN_LIBRARY", library));
        out = assert_native_identity(str(program));
    }
    for expected in [
        "set 1 41",
        "double 82",
        "bump 90",
        "read 70",
        "struct 3.0 4.0 6.0",
        "pointer 9.0",
        "field 18 3.0"
    ] {
        assert expected in out.splitlines() , f"missing {expected!r} in:\n{out}";
    }
}

test "only a C function's ptr[T] parameter borrows a variable of exactly T" {
    code = '''import from "CLIB_POINTERS_LIBRARY" {
    def cp_lend_i64(out: ptr[i64]) -> None;
}
def jac_takes(p: ptr[i64]) -> None {
    print(p);
}
with entry {
    n: i64 = 0;
    small: i32 = 0;
    cp_lend_i64(&mut n);
    cp_lend_i64(&mut small);
    jac_takes(&mut n);
}
''';
    assert checker_codes(code) == ["E1053", "E1053"];
}
