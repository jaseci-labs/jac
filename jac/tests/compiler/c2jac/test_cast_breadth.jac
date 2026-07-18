"""CastBuildPass fixture-breadth coverage (phase1 Step C).

`test_cast_slice` pins the *precise* output of the core vertical slice; this
file ports the breadth the retired two-hop suite exercised — every fixture the
old tests fed through the transpiler. Two guarantees per fixture:

  1. the lifted module is valid *compiler input* (recompiles with no errors);
  2. it emits exactly the faithfulness diagnostics we expect (the E/W 4200-band
     that replaced the two-hop Idiom/Tier/Mechanism tag taxonomy).

Targeted tests below additionally lock the faithful *output* shape of the
constructs the slice suite doesn't cover (for-loop lowering variants, the
CPython real-world files, module-scope globals/typedefs, reserved-keyword
identifiers).
"""

import from jaclang.compiler.cfront.lift { lift_c_str, lift_c_file }
import from tests.compiler.c2jac.support {
    BREADTH,
    read_fixture as _read,
    recompile_errors as _recompile
}

test "every fixture lifts to Jac that recompiles with zero errors" {
    broken: list = [];
    for (name, _) in BREADTH {
        res = lift_c_str(_read(name), name);
        out = res.module.unparse(requires_format=True);
        errs = _recompile(out, name);
        if errs {
            broken.append((name, [str(e).splitlines()[0] for e in errs]));
        }
    }
    assert broken == [] , f"fixtures emitted non-recompilable Jac: {broken}";
}

test "every fixture emits exactly its expected faithfulness diagnostics" {
    mismatched: list = [];
    for (name, expected) in BREADTH {
        res = lift_c_str(_read(name), name);
        got = sorted([d[0] for d in res.diags]);
        if got != sorted(expected) {
            mismatched.append((name, got, sorted(expected)));
        }
    }
    assert mismatched == [] , f"diagnostic-code mismatches (name, got, want): {mismatched}";
}

test "minilib/vec2.c lifts through the .c preprocess path (struct methods)" {
    res = lift_c_file(_read_path("minilib/vec2.c"));
    out = res.module.unparse(requires_format=True);
    assert "obj Vec2 {" in out , out;
    assert "def vec2_add(a: Vec2, b: Vec2) -> Vec2 {" in out;
    assert res.diags == [] , res.diags;
}

def _read_path(name: str) -> str {
    import os;
    import from tests.support { JAC_ROOT }
    return os.path.join(JAC_ROOT, "tests", "compiler", "c2jac", "fixtures", name);
}

# ---- targeted faithful-output locks (constructs not in test_cast_slice) ----
test "for_continue.c promotes descending for-with-continue to IterForStmt" {
    res = lift_c_str(_read("for_continue.c"), "for_continue.c");
    out = res.module.unparse(requires_format=True);
    # `>`/`>=` are promotable; Jac IterForStmt runs count_by on continue, so
    # the C `for` step is faithful and no W4208 quarantine is needed.
    assert "for i = n to i > 0 by" in out , out;
    assert "continue;" in out;
    assert res.diags == [] , res.diags;
    assert res.quarantined_functions == [];
}

test "for_comma.c promotes past a pure comma-init and flags a dropped operand" {
    res = lift_c_str(_read("for_comma.c"), "for_comma.c");
    out = res.module.unparse(requires_format=True);
    assert "for i = 0 to i < n by i += 1 {" in out , out;
    assert res.diags[0][0] == "W4204";
}

test "for_cast.c elides a representation-changing cast in the body (W4201)" {
    res = lift_c_str(_read("for_cast.c"), "for_cast.c");
    out = res.module.unparse(requires_format=True);
    # Known-int `/` lowers to `//` (C truncating divide); the `(int)` cast
    # itself is still elided as W4201.
    assert "total = total + (i // 2);" in out , out;
    assert res.diags[0][0] == "W4201";
}

test "for_ternary.c lifts a body ternary to a Jac if-else expression" {
    res = lift_c_str(_read("for_ternary.c"), "for_ternary.c");
    out = res.module.unparse(requires_format=True);
    assert "s += hi if (i > hi) else i;" in out , out;
    assert res.diags == [] , res.diags;
}

test "switch_fallthrough.c flags fall-through and quarantines the function" {
    res = lift_c_str(_read("switch_fallthrough.c"), "switch_fallthrough.c");
    out = res.module.unparse(requires_format=True);
    # W4202 is behavior-band: containing function becomes a call-time trap
    assert res.diags[0][0] == "W4202";
    assert res.quarantined_functions;
    assert "quarantined function" in out , out;
    assert "raise" in out;
}

test "do_while_continue.c flags W4203 and quarantines the function" {
    res = lift_c_str(_read("do_while_continue.c"), "do_while_continue.c");
    out = res.module.unparse(requires_format=True);
    assert res.diags[0][0] == "W4203";
    assert res.quarantined_functions;
    assert "quarantined function" in out , out;
    assert "raise" in out;
}

test "struct_array.c lifts an object array + subscript member assign" {
    res = lift_c_str(_read("struct_array.c"), "struct_array.c");
    out = res.module.unparse(requires_format=True);
    assert "has x: int = 0;" in out , out;
    assert "a: list[S] = [S() for _ in range(2)];" in out , out;
    assert "a[0].x = 1;" in out;
    assert res.diags == [] , res.diags;
}

test "for_funcall_step.c lifts a module-scope global as `glob`" {
    res = lift_c_str(_read("for_funcall_step.c"), "for_funcall_step.c");
    out = res.module.unparse(requires_format=True);
    # C BSS-zeroed globals become `glob` with an explicit zero; functions that
    # assign them need `global name;` (Jac/Python local-binding rule).
    assert "glob counter: int = 0;" in out , out;
    assert "global counter;" in out , out;
    assert "def tick() -> None {" in out;
    assert res.diags == [] , res.diags;
}

test "nonascii_str.c lifts module string globals with `glob`" {
    res = lift_c_str(_read("nonascii_str.c"), "nonascii_str.c");
    out = res.module.unparse(requires_format=True);
    assert 'glob cafe: str = "café";' in out , out;
}

test "cpython/pystrcmp.c lifts a real-world file (walrus loop cond, ternary)" {
    res = lift_c_str(_read("cpython/pystrcmp.c"), "cpython/pystrcmp.c");
    out = res.module.unparse(requires_format=True);
    assert "def py_tolower(c: int) -> int {" in out , out;
    # a comma-operator loop condition folds the assignment into a walrus
    assert "(size := size - 1)" in out;
    # char* cursors: deref → ord(...), advance → suffix slice
    assert "ord(" in out , out;
    assert "p1 = p1[1:];" in out or "p1 = p1[1 :];" in out , out;
    assert res.diags == [] , res.diags;
}

test "cpython/mysnprintf.c lifts a scalar typedef to `glob` + flags its variadic" {
    res = lift_c_str(_read("cpython/mysnprintf.c"), "cpython/mysnprintf.c");
    out = res.module.unparse(requires_format=True);
    # `typedef ... va_list` -> a module `glob` alias (not a bare assignment)
    assert "glob va_list = " in out , out;
    # `PyOS_snprintf(..., ...)` is variadic -> the one faithful hole (W4207)
    assert [d[0] for d in res.diags] == ["W4207"] , res.diags;
}

test "cpython/rotatingtree.c escapes reserved-keyword C identifiers" {
    res = lift_c_str(_read("cpython/rotatingtree.c"), "cpython/rotatingtree.c");
    out = res.module.unparse(requires_format=True);
    # C params named `root` / `node` collide with reserved Jac keywords: they
    # are escaped with a single leading backtick so the lift stays valid Jac.
    assert "def RotatingTree_Add(`root: object, `node: rotating_node_t)" in out , out;
    assert "`node.left = NULL;" in out;
    assert res.diags == [] , res.diags;
}
