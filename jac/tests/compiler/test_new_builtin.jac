"""Tests for the `new` ambient builtin.

`new(Cls, ...args)` is a portable, codespace-aware constructor:
  * In server/Python target code it lowers to `Cls(*args)`.
  * In `cl` (client / JavaScript) blocks it lowers to
    `Reflect.construct(Cls, [args])`.

This replaces the previous client-only `Reflect.construct(...)` idiom and
lets the same source compile cleanly in both backends.
"""

import os;
import tempfile;
import from pathlib { Path }
import from tempfile { NamedTemporaryFile }
import jaclang;
import from jaclang.jac0core.parser.parser { parse }
import from jaclang.jac0core.passes.ast_validation_pass { ASTValidationPass }
import from jaclang.jac0core.program { JacProgram }

glob _test_tmp_dir: str = tempfile.mkdtemp(prefix="jac_test_new_builtin_");

"""Compile inline Jac source through a fresh JacProgram and return module."""
def compile_inline(code: str, prog: JacProgram | None = None) -> object {
    with NamedTemporaryFile(
        mode="w", suffix=".jac", delete=False, dir=_test_tmp_dir
    ) as f {
        f.write(code);
        f.flush();
        if prog is None {
            prog = JacProgram();
        }
        mod = prog.compile(f.name);
        os.unlink(f.name);
        return mod;
    }
}

"""Parse + validate, returning the JacProgram so we can inspect diagnostics."""
def parse_and_validate(source: str) -> JacProgram {
    prog = JacProgram();
    (module, _) = parse(source, "/tmp/test_new_builtin.jac", prog=prog);
    if module is not None {
        ASTValidationPass(ir_in=module, prog=prog);
    }
    return prog;
}

"""Check whether a specific diagnostic code was emitted."""
def has_code(prog: JacProgram, code: str) -> bool {
    for d in prog.errors_had {
        if d.code is not None and d.code.code == code {
            return True;
        }
    }
    return False;
}


# ─────────────────────────────────────────────────────────────────────
#  Validation: `new(...)` must NOT trigger the legacy E0010 rejection
# ─────────────────────────────────────────────────────────────────────
test "new() as a call is not flagged by ast_validation_pass" {
    prog = parse_and_validate("with entry { x = new(list, [1, 2, 3]); }");
    assert not has_code(prog, "E0010") , (
        "new(...) used as a function call must be allowed (E0010 should not fire)"
    );
}

test "new as a bare identifier (function reference) is allowed" {
    prog = parse_and_validate("with entry { f = new; }");
    assert not has_code(prog, "E0010") , (
        "Passing `new` as a first-class function reference must be allowed"
    );
}

test "JS-style `new Foo()` keyword usage still errors" {
    # `new Foo(1, 2)` is not Jac syntax: it should still fail to parse
    # (or fail validation). We only require *some* error, not a specific code.
    prog = parse_and_validate("with entry { x = new Foo(1, 2); }");
    assert len(prog.errors_had) > 0 , (
        "JS-style `new Foo()` must continue to be rejected"
    );
}


# ─────────────────────────────────────────────────────────────────────
#  Client (cl) backend: `new(...)` → `Reflect.construct(...)`
# ─────────────────────────────────────────────────────────────────────
test "cl: new(Cls, args) lowers to Reflect.construct in JS output" {
    code = "cl def make_date(s: str) -> Any {\n" + "    return new(Date, s);\n" + "}\n";
    mod = compile_inline(code);
    js = mod.gen.js;
    assert js.strip() , "Expected JavaScript output for cl code";
    assert "Reflect.construct(Date, [s])" in js , (
        "new(Date, s) must lower to Reflect.construct(Date, [s]); got:\n" + js
    );
    assert "new(" not in js , (
        "Raw `new(` call must not leak into JS output; emitter should rewrite it"
    );
}

test "cl: new(Cls) with no args lowers to Reflect.construct(Cls, [])" {
    code = "cl def make_set() -> Any {\n" + "    return new(Set);\n" + "}\n";
    mod = compile_inline(code);
    js = mod.gen.js;
    assert "Reflect.construct(Set, [])" in js , (
        "new(Set) with no args must lower to Reflect.construct(Set, []); got:\n" + js
    );
}

test "cl: new with multiple args produces a JS array of args" {
    code = "cl def mk(a: int, b: int) -> Any {\n" + "    return new(Map, a, b);\n" + "}\n";
    mod = compile_inline(code);
    js = mod.gen.js;
    assert "Reflect.construct(Map, [a, b])" in js , (
        "new(Map, a, b) must lower to Reflect.construct(Map, [a, b]); got:\n" + js
    );
}


# ─────────────────────────────────────────────────────────────────────
#  Server (Python) backend: `new(...)` works as an ambient builtin
# ─────────────────────────────────────────────────────────────────────
test "server: new is auto-imported from runtimelib.builtin" {
    code = "with entry { x = new(list, [1, 2, 3]); print(x); }\n";
    mod = compile_inline(code);
    py = mod.gen.py;
    assert "from jaclang.runtimelib.builtin import" in py , (
        "Expected builtin import preamble; got:\n" + py
    );
    assert "new" in py , "Expected `new` to appear in generated Python";
}

test "server: new(Cls, *args) returns Cls(*args) at runtime" {
    import from jaclang.runtimelib.builtin { new }
    class Box {
        def init(self, x: int, y: int) {
            self.x = x;
            self.y = y;
        }
    }
    b = new(Box, 3, 4);
    assert isinstance(b, Box);
    assert b.x == 3 and b.y == 4;
}

test "server: new with builtin types works end-to-end" {
    import from jaclang.runtimelib.builtin { new }
    assert new(list, [1, 2, 3]) == [1, 2, 3];
    assert new(dict, {"a": 1}) == {"a": 1};
    assert new(set, [1, 2, 2, 3]) == {1,2,3};
}


# ─────────────────────────────────────────────────────────────────────
#  Diagnostic: E0012 should now point at `new(...)`, not `Reflect.construct`
# ─────────────────────────────────────────────────────────────────────
test "E0012 message mentions new(...) idiom" {
    import from jaclang.jac0core.diagnostics { E0012 }
    msg = E0012.message_template;
    assert "new(" in msg , (
        "E0012 should recommend `new(target, ...args)`; current template: " + msg
    );
}
