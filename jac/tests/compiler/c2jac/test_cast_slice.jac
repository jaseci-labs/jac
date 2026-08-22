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

test "for_ptr_idiom.c elides realloc on pointer params inside loops" {
    src = _read("for_ptr_idiom.c");
    res = lift_c_str(src, "for_ptr_idiom.c");
    out = res.module.unparse(requires_format=True);
    assert "def sum_then_free(n: int, p: object) -> int {" in out , out;
    assert "s += p[i];" in out;
    assert "def grow_in_loop(n: int, arr: object) -> int {" in out;
    assert "arr = arr;" in out;
    assert "s += arr[i];" in out;
    assert "__c_unsupported__(" not in out;
    assert res.diags == [] , f"expected no diags, got {res.diags}";
}

test "edge_cases.c lifts goto_test and pointer_arithmetic idioms" {
    src = _read("edge_cases.c");
    res = lift_c_str(src, "edge_cases.c");
    out = res.module.unparse(requires_format=True);
    assert "def goto_test(n: int) -> int {" in out , out;
    assert "while (i < n) {" in out , out;
    assert "def pointer_arithmetic(arr: object, n: int) -> int {" in out , out;
    assert "sum += p;" in out , out;
    assert "p += 1;" in out , out;
    assert "goto_test" not in res.quarantined_functions , res.quarantined_functions;
    assert "pointer_arithmetic" not in res.quarantined_functions , res.quarantined_functions;
}

test "postfix increment lowers to a walrus expression for scalars" {
    src = "int f(int i) { return i++; }\n";
    res = lift_c_str(src, "postfix_inc.c");
    out = res.module.unparse(requires_format=True);
    assert "return (i := i + 1 - 1);" in out , out;
    assert res.quarantined_functions == [] , res.quarantined_functions;
}

test "cfor.c promotes a C for-loop to a Jac IterForStmt" {
    src = _read("cfor.c");
    res = lift_c_str(src, "cfor.c");
    out = res.module.unparse(requires_format=True);
    assert "for i = 0 while i < n with i += 1 {" in out , out;
    assert "continue;" in out;
    # `sum_for` and `count_odds` both promote faithfully; the `i % 2` parity
    # test lowers to a C-semantics `c_imod` call (no W4213 -- C truncates toward
    # zero where Jac `%` floors), so the lift is diag-free and neither function
    # quarantines.
    assert res.diags == [] , res.diags;
    assert "c_imod(" in out , out;
}

test "for_incdec_body.c lowers statement-position ++/-- to augassign" {
    src = _read("for_incdec_body.c");
    res = lift_c_str(src, "for_incdec_body.c");
    out = res.module.unparse(requires_format=True);
    assert "for i = 0 while i < n with i += 1 {" in out , out;
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
    assert "enum Permissions { PERM_READ = 1, PERM_WRITE = 2, PERM_EXEC = 4, PERM_ALL = 7 }"
        in out , out;
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

test "enum_tu_collision.c hoists non-colliding enum consts and prefixes func collisions" {
    src = _read("enum_tu_collision.c");
    res = lift_c_str(src, "enum_tu_collision.c");
    out = res.module.unparse(requires_format=True);
    # STATUS_OK collides with the module function — hoisted under `_enum_STATUS_OK`
    assert "def STATUS_OK() -> int {" in out , out;
    assert "glob _enum_STATUS_OK = 1;" in out;
    assert "glob STATUS_ERR = 2;" in out;
    assert "glob g_state: int;" in out;
    assert "return STATUS_ERR;" in out;
    assert "__c_unsupported__(" not in out;
    assert res.diags == [] , f"expected no diags, got {res.diags}";
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

test "null_sentinel.c lowers C NULL to Jac None" {
    src = _read("null_sentinel.c");
    res = lift_c_str(src, "null_sentinel.c");
    out = res.module.unparse(requires_format=True);
    assert "== None" in out , out;
    assert "!= None" in out , out;
    assert "= None;" in out , out;
    assert "NULL" not in out , out;
    assert res.diags == [] , res.diags;
}

test "refcount_err_return.c elides refcount ops and lifts PyErr returns" {
    src = _read("refcount_err_return.c");
    res = lift_c_str(src, "refcount_err_return.c");
    out = res.module.unparse(requires_format=True);
    assert "Py_INCREF" not in out , out;
    assert "Py_DECREF" not in out , out;
    assert "Py_XDECREF" not in out , out;
    assert "Py_CLEAR" not in out , out;
    assert "Py_NewRef" not in out , out;
    assert "Py_XNewRef" not in out , out;
    assert "PyErr_SetString" not in out.split("def fail_value")[1].split("def ")[0] , out;
    assert "PyErr_SetString" not in out.split("def fail_int")[1].split("def ")[0] , out;
    assert 'raise ValueError("bad arg")' in out , out;
    assert 'raise TypeError("wrong type")' in out , out;
    assert "slot = None" in out , out;
    assert "return `obj" in out , out;
    assert "def borrow(`obj: PyObj)" in out , out;
    assert "def get_item(lst: PyObj, i: int) -> PyObj" in out , out;
    assert res.diags == [] , res.diags;
}

test "pyobj_types.c maps PyObject pointers to PyObj" {
    src = _read("pyobj_types.c");
    res = lift_c_str(src, "pyobj_types.c");
    out = res.module.unparse(requires_format=True);
    assert "def identity(`obj: PyObj) -> PyObj" in out , out;
    assert "def clear_slot(slot: PyObj) -> None" in out , out;
    assert "def maybe(`obj: PyObj) -> PyObj" in out , out;
    assert "PyObject" not in out , out;
    assert "NULL" not in out , out;
    assert res.diags == [] , res.diags;
}

test "fn_ptr_callback.c lifts function-pointer typedefs to callback objs" {
    src = _read("fn_ptr_callback.c");
    res = lift_c_str(src, "fn_ptr_callback.c");
    out = res.module.unparse(requires_format=True);
    assert "obj comparator {" in out , out;
    assert "def call(a: object, b: object) -> int" in out , out;
    assert "def invoke(cmp: comparator, x: int, y: int) -> int" in out , out;
    assert "glob comparator = " not in out , out;
    assert res.diags == [] , res.diags;
}

test "string_table.c lifts char[] lookup tables to list[int] ord values" {
    src = _read("string_table.c");
    res = lift_c_str(src, "string_table.c");
    out = res.module.unparse(requires_format=True);
    assert "glob _hexdigits: list[int] = [" in out , out;
    assert "48" in out and "102" in out , out;
    assert '"0123456789abcdef"' not in out , out;
    assert "_hexdigits[(value >> 4)]" in out , out;
    assert res.diags == [] , res.diags;
}

test "string_blob.c keeps char[] string literals when not subscripted" {
    src = _read("string_blob.c");
    res = lift_c_str(src, "string_blob.c");
    out = res.module.unparse(requires_format=True);
    assert 'glob msg: list[int] = "hello world"' in out , out;
    assert "return msg" in out , out;
    assert res.diags == [] , res.diags;
}

test "pystrnicmp_mini.c absorbs byte-trunc and int-widen casts" {
    src = _read("pystrnicmp_mini.c");
    res = lift_c_str(src, "pystrnicmp_mini.c");
    out = res.module.unparse(requires_format=True);
    assert "& 255" in out , out;
    assert "def _py_tolower(c: int) -> int {" in out , out;
    assert res.diags == [] , res.diags;
}

test "sparse_designated_array.c preserves sparse struct array indices" {
    src = _read("sparse_designated_array.c");
    res = lift_c_str(src, "sparse_designated_array.c");
    out = res.module.unparse(requires_format=True);
    assert "glob t: list[S] = [" in out , out;
    assert "a=10" in out or "a = 10" in out , out;
    assert "W4209" not in [d[0] for d in res.diags] , res.diags;
    assert res.diags == [] , res.diags;
}

test "opcode_table_mini.c lifts sparse opcode metadata table" {
    src = _read("opcode_table_mini.c");
    res = lift_c_str(src, "opcode_table_mini.c");
    out = res.module.unparse(requires_format=True);
    assert "glob _PyOpcode_opcode_metadata: list[opcode_metadata] = [" in out , out;
    assert ".valid_entry" in out , out;
    assert "W4209" not in [d[0] for d in res.diags] , res.diags;
    assert res.diags == [] , res.diags;
}

test "stat_mask.c parses C octal masks and elides mode_t casts" {
    src = _read("stat_mask.c");
    res = lift_c_str(src, "stat_mask.c");
    out = res.module.unparse(requires_format=True);
    assert "4095" in out , out;
    assert "'07777'" not in out , out;
    assert "W4210" not in [d[0] for d in res.diags] , res.diags;
    assert "W4201" not in [d[0] for d in res.diags] , res.diags;
    assert res.diags == [] , res.diags;
}
