"""CastBuildPass direct-lift vertical slice (phase1 Step 4).

Locks in the first end-to-end slice through the new pass: FileAST/FuncDef/
Compound/Decl/Return/BinaryOp/ID/Constant/FuncCall on hello.c, with no
diagnostics. Grows as §A/§B methods land.
"""

import os;
import tempfile;
import from jaclang.compiler.cfront.lift {
    lift_c_str,
    transpile_c_str,
    lift_c_file,
    render_c2jac_report
}
import from tests.compiler.c2jac.support { read_fixture as _read }

def _write_i(src: str) -> str {
    # Materialize `src` as a preprocessed `.i` so `lift_c_file` skips pcpp.
    path = os.path.join(tempfile.mkdtemp(), "unit.i");
    with open(path, "w") as f {
        f.write(src);
    }
    return path;
}

test "hello.c lifts to faithful Jac via CastBuildPass" {
    src = _read("hello.c");
    out = transpile_c_str(src, "hello.c");
    assert "def add(a: int, b: int) -> int {" in out , out;
    assert "total: int = a + b;" in out;
    assert "return total;" in out;
    assert "def main() -> int {" in out;
    assert "x: int = add(2, 3);" in out;
    assert "return x;" in out;
}

test "hello.c lift emits zero faithfulness diagnostics" {
    src = _read("hello.c");
    res = lift_c_str(src, "hello.c");
    assert res.diags == [] , f"expected no diags, got {res.diags}";
}

test "control_flow.c lifts if/elif/else, while, break/continue, augassign" {
    src = _read("control_flow.c");
    res = lift_c_str(src, "control_flow.c");
    out = res.module.unparse(requires_format=True);
    # if / else-if / else chain with a boolean condition
    assert "if ((x > 0) and (x < 100)) {" in out , out;
    assert "} elif (x == 0) {" in out;
    assert "} else {" in out;
    assert "return -1;" in out;
    # while + augmented assignment
    assert "while (i < n) {" in out;
    assert "total += i;" in out;
    # array subscript, break, continue
    assert "if (arr[i] == target) {" in out;
    assert "break;" in out;
    assert "continue;" in out;
    assert res.diags == [] , f"expected no diags, got {res.diags}";
}

test "ternary.c lifts to a Jac if-else expression" {
    src = _read("ternary.c");
    res = lift_c_str(src, "ternary.c");
    out = res.module.unparse(requires_format=True);
    assert "return a if (a > 0) else -a;" in out , out;
    assert res.diags == [] , f"expected no diags, got {res.diags}";
}

test "struct_shape.c lifts C structs to faithful Jac obj/has (not with-entry)" {
    src = _read("struct_shape.c");
    res = lift_c_str(src, "struct_shape.c");
    out = res.module.unparse(requires_format=True);
    # direct-lift builds a real archetype + has-vars, unlike the two-hop
    # `class`/`with entry` artifact
    assert "obj Point {" in out , out;
    assert "has x: int = 0;" in out;
    assert "has z: float = 0.0;" in out;
    assert "obj Record {" in out;
    assert "obj Node {" in out;
    assert "def point_sum() -> int {" in out;
    assert "p: Point = Point();" in out;
    assert "def point_init_sum() -> int {" in out;
    assert "p: Point = Point(x=3, y=4, z=0);" in out;
    assert "def point_desig_sum() -> int {" in out;
    assert "p: Point = Point(x=3, y=4);" in out;
    assert "with entry" not in out;
    assert res.diags == [] , f"expected no diags, got {res.diags}";
}

test "arrays.c lifts fixed array decl + subscript assign/read" {
    src = _read("arrays.c");
    res = lift_c_str(src, "arrays.c");
    out = res.module.unparse(requires_format=True);
    assert "arr: list[int] = [0] * 5;" in out , out;
    assert "arr[0] = 10;" in out;
    assert "total += arr[i];" in out;
    assert "return arr[0];" in out;
    assert res.diags == [] , f"expected no diags, got {res.diags}";
}

test "pointers.c folds malloc/free/`->` to faithful GC'd Jac" {
    src = _read("pointers.c");
    res = lift_c_str(src, "pointers.c");
    out = res.module.unparse(requires_format=True);
    # malloc(sizeof(T)) -> T(); free() elides; p->x -> p.x
    assert "p: Point = Point();" in out , out;
    assert "p.x = x;" in out;
    assert "return p.x;" in out;
    assert res.diags == [] , f"expected no diags, got {res.diags}";
}

test "ptr_idioms.c folds malloc-array/realloc/deref/address-of" {
    src = _read("ptr_idioms.c");
    res = lift_c_str(src, "ptr_idioms.c");
    out = res.module.unparse(requires_format=True);
    # malloc(n*sizeof(T)) -> list comprehension; realloc on list-bound elides
    assert "arr: list[Point] = [Point() for _ in range(n)];" in out , out;
    assert "arr = arr;" in out;
    # `*p` and `(*p).x` / `p->y` and `&p->x` fold to the simple ref (silent)
    assert "copy: Point = p;" in out;
    assert "total: int = p.x + p.y;" in out;
    assert "set_field(p.x, v);" in out;
    assert res.diags == [] , f"expected no diags, got {res.diags}";
}

test "cfor.c promotes a C for-loop to a Jac IterForStmt" {
    src = _read("cfor.c");
    res = lift_c_str(src, "cfor.c");
    out = res.module.unparse(requires_format=True);
    assert "for i = 0 to i < n by i += 1 {" in out , out;
    assert "continue;" in out;
    assert res.diags == [] , f"expected no diags, got {res.diags}";
}

test "for_incdec_body.c lowers statement-position ++/-- to augassign" {
    src = _read("for_incdec_body.c");
    res = lift_c_str(src, "for_incdec_body.c");
    out = res.module.unparse(requires_format=True);
    assert "for i = 0 to i < n by i += 1 {" in out , out;
    assert "s += 1;" in out;
    assert "s -= 1;" in out;
    assert res.diags == [] , f"expected no diags, got {res.diags}";
}

test "do_while.c desugars to `while True` with a post-body break guard" {
    src = _read("do_while.c");
    res = lift_c_str(src, "do_while.c");
    out = res.module.unparse(requires_format=True);
    assert "while True {" in out , out;
    assert "s = s + n;" in out;
    assert "n = n - 1;" in out;
    assert "if not (n > 0) {" in out;
    assert "break;" in out;
    assert res.diags == [] , f"expected no diags, got {res.diags}";
}

test "obj_array.c lifts an object fixed array to a range comprehension" {
    src = _read("obj_array.c");
    res = lift_c_str(src, "obj_array.c");
    out = res.module.unparse(requires_format=True);
    # `struct Point pts[4];` -> `[Point() for _ in range(4)]` (not `[0] * 4`)
    assert "pts: list[Point] = [Point() for _ in range(4)];" in out , out;
    assert "pts[0].x = n;" in out;
    assert "return pts[0].x;" in out;
    assert res.diags == [] , f"expected no diags, got {res.diags}";
}

test "enum_simple.c lifts to a faithful Jac enum + re-qualifies member refs" {
    src = _read("enum_simple.c");
    res = lift_c_str(src, "enum_simple.c");
    out = res.module.unparse(requires_format=True);
    # each C enum becomes a real Jac `enum` (not the two-hop `enum` + `with entry`)
    assert "enum Color { RED = 0, GREEN = 1, BLUE = 2 }" in out , out;
    assert "enum Direction { NORTH = 0, EAST = 1, SOUTH = 2, WEST = 3 }" in out;
    assert "with entry" not in out;
    # a bare `return GREEN;` is re-qualified to the owning enum: `Color.GREEN`
    assert "return Color.GREEN;" in out;
    assert res.diags == [] , f"expected no diags, got {res.diags}";
}

test "enum_flags.c lifts an enum whose members are unreferenced (no rewrite)" {
    src = _read("enum_flags.c");
    res = lift_c_str(src, "enum_flags.c");
    out = res.module.unparse(requires_format=True);
    assert "enum Permissions { PERM_READ = 1, PERM_WRITE = 2, PERM_EXEC = 4, PERM_ALL = 7 }" in out , out;
    assert "def has_read(p: int) -> int {" in out;
    assert res.diags == [] , f"expected no diags, got {res.diags}";
}

test "enum_collision.c lowers function-local enums to scoped int consts" {
    src = _read("enum_collision.c");
    res = lift_c_str(src, "enum_collision.c");
    out = res.module.unparse(requires_format=True);
    # a `enum { VAL_A = 0, ... } e1;` inside a function body becomes local int
    # bindings (not a module hoist) — so the same name in two functions is fine
    assert "def test_a() -> int {" in out , out;
    assert "VAL_A = 0;" in out;
    assert "VAL_B = 1;" in out;
    assert "e1: int;" in out;
    # test_b re-uses VAL_A with a different value in its own scope — no collision
    assert "VAL_A = 10;" in out;
    assert "VAL_C = 11;" in out;
    assert res.diags == [] , f"expected no diags, got {res.diags}";
}

test "enum_tu_collision.c surrogates a hoist that collides with a function name" {
    src = _read("enum_tu_collision.c");
    res = lift_c_str(src, "enum_tu_collision.c");
    out = res.module.unparse(requires_format=True);
    # `enum { STATUS_OK = 1, ... } g_state;` at module scope can't hoist —
    # STATUS_OK collides with the module function — so it flags a 4290 hole
    assert "__c_unsupported__(" in out , out;
    assert "g_state: int;" in out;
    assert len(res.diags) == 1 , res.diags;
    assert res.diags[0][0] == "W4290";
}

test "switch_basic.c lowers a clean switch to an if/elif chain (no diag)" {
    src = _read("switch_basic.c");
    res = lift_c_str(src, "switch_basic.c");
    out = res.module.unparse(requires_format=True);
    assert "if x == 1 or x == 2 {" in out , out;
    assert "} elif x == 3 {" in out;
    assert "r = 10;" in out;
    assert "r = 20;" in out;
    assert "r = -1;" in out;
    # every case ends in break + pure selector -> faithful, no 4202
    assert res.diags == [] , f"expected no diags, got {res.diags}";
}

test "lift_c_file lifts a preprocessed .i (Step 6 driver entry point)" {
    path = _write_i("int add(int a, int b){ return a + b; }\n");
    res = lift_c_file(path);
    out = res.module.unparse(requires_format=True);
    assert "def add(a: int, b: int) -> int {" in out , out;
    assert res.diags == [] , f"expected no diags, got {res.diags}";
    # a faithful lift produces an empty `# c2jac:` report header
    assert render_c2jac_report(res.diags) == "";
}

test "lenient vs strict lift pick the W/E diagnostic twin for the same site" {
    path = _write_i("int f(int a){ char c = (char)a; return c; }\n");
    lenient = lift_c_file(path, lenient_c=True);
    strict = lift_c_file(path, lenient_c=False);
    assert len(lenient.diags) == 1 , lenient.diags;
    assert len(strict.diags) == 1;
    # same cast site, twinned severity: W4201 (lenient) vs E4201 (strict)
    assert lenient.diags[0][0] == "W4201";
    assert strict.diags[0][0] == "E4201";
    # the report header renders one line per flagged site
    header = render_c2jac_report(lenient.diags);
    assert "# c2jac: 1 best-effort site" in header , header;
    assert "[W4201]" in header;
}
