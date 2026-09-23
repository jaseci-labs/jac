"""Method-kind keywords lower natively; the Python decorator spellings do not.

Jac has first-class syntax for all three method kinds -- `abst`, `class def`,
`static def` -- which the parser turns into `uni.Ability` flags
(`is_abstract` / `is_classmethod` / `is_static`) and `pyast_gen` re-emits as
`@abstractmethod` / `@classmethod` / `@staticmethod` on the Python backend.

The native capability authority inspects `nd.decorators`, a list of `Expr`
nodes. A keyword populates no such list, so the keyword forms cross the
native boundary while the hand-written decorators demote their method to a
Python-only seam (granular demotion, epic #8201) -- the method leaves the
native layout rather than running undecorated. The compiler's own front-end
sources used the decorator spellings in places (`passes/transform.jac`,
`runtime.jac`, `compiler.jac`); this test pins both halves of the contract
so that regression is visible.

`@abstractmethod` is the one spelling that cannot be written without also
importing it, and a module-scope Python import has no owning callable to
absorb it, so that snippet refuses the whole module rather than seaming one
method. `@classmethod` is a builtin and needs no import, which is where the
granular half of the decorator contract is pinned.

Tracks the front-end native idiom work in #8039.
"""

import ctypes;
import os;
import from tests.support {
    TESTS_DIR,
    compile_native,
    get_func,
    has_error_code,
    native_force_opts
}
import jaclang;
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

"""Run a snippet through the front-end check schedule with the native
capability authority on -- the `jac check` path that surfaces E5090."""
def check_na_inline(label: str, code: str) -> JacProgram {
    prog = JacProgram();
    prog.compile(
        file_path=os.path.join(FIXTURES, f"_mkind_{label}.jac"),
        use_str=code,
        options=CompileOptions(no_cgen=True, force_codespace="native")
    );
    return prog;
}

"""Format errors for assertion messages."""
def fmt_errors(prog: JacProgram) -> str {
    return str([str(e) for e in prog.errors_had]);
}

# ─────────────────────────────────────────────────────────────────────
# The keyword forms lower and behave
# ─────────────────────────────────────────────────────────────────────

test "abst: an abstract declaration lowers and its override runs" {
    (eng, _) = compile_native("method_kind_keywords.jac");
    f = get_func(eng, "call_abstract_impl", ctypes.c_int64, ctypes.c_int64);
    assert f(5) == 25;
    assert f(0) == 0;
}

test "abst: dispatch through the abstract base reaches the override" {
    (eng, _) = compile_native("method_kind_keywords.jac");
    f = get_func(eng, "call_abstract_through_base", ctypes.c_int64, ctypes.c_int64);
    assert f(7) == 49;
}

test "static def: a staticmethod lowers and returns its value" {
    (eng, _) = compile_native("method_kind_keywords.jac");
    f = get_func(eng, "call_staticmethod", ctypes.c_int64, ctypes.c_int64);
    assert f(41) == 42;
}

test "class def: a classmethod lowers receiver-less and carries its arguments" {
    (eng, _) = compile_native("method_kind_keywords.jac");
    f = get_func(eng, "call_classmethod", ctypes.c_int64, ctypes.c_int64);
    assert f(5) == 17;
    assert f(0) == 7;
}

test "the keyword fixture compiles with no native diagnostics at all" {
    prog = JacProgram();
    prog.compile(
        file_path=str(os.path.join(FIXTURES, "method_kind_keywords.jac")),
        options=native_force_opts()
    );
    assert not prog.errors_had , fmt_errors(prog);
}

# ─────────────────────────────────────────────────────────────────────
# The decorator spellings demote off native -- this is why the sources moved
# ─────────────────────────────────────────────────────────────────────

test "guardrail: @abstractmethod refuses where abst is accepted" {
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, "_mkind_abstractmethod.jac"),
        use_str="import from abc { abstractmethod }\n"
        "obj Base {\n"
        "    @abstractmethod\n"
        "    def go(x: int) -> int;\n"
        "}\n"
        "obj Impl(Base) {\n"
        "    def go(x: int) -> int { return x + 1; }\n"
        "}\n"
        "with entry { print(Impl().go(1)); }\n",
        options=native_force_opts()
    );
    errs = fmt_errors(prog);
    assert "decorator 'on go'" in errs , (
        f"the capability gate must still name the decorator spelling: {errs}"
    );
    assert "Python module import 'abc'" in errs , (
        "the decorator cannot be written without importing it, and a "
        "module-scope Python import has no owning callable to absorb it as "
        "a seam. `import abc;` has always refused the whole module here; "
        f"the `from` spelling is classified on the same terms: {errs}"
    );
    assert ir.gen.llvm_ir is None , (
        "a module-fatal violation must withhold the LLVM IR"
    );
    kw = check_na_inline(
        "abst",
        "obj Base {\n"
        "    def go(x: int) -> int abst;\n"
        "}\n"
        "obj Impl(Base) {\n"
        "    def go(x: int) -> int { return x + 1; }\n"
        "}\n"
        "with entry { print(Impl().go(1)); }\n"
    );
    assert not kw.errors_had , fmt_errors(kw);
}

test "guardrail: @classmethod demotes at the capability gate" {
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, "_mkind_classmethod.jac"),
        use_str="obj Holder {\n"
        "    @classmethod\n"
        "    def make(cls: any) -> int { return 7; }\n"
        "}\n",
        options=native_force_opts()
    );
    assert not has_error_code(prog, "E5090") , (
        f"a @classmethod method must demote, not fail the module: {fmt_errors(prog)}"
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "Holder.make" not in layout.methods , (
        "the @classmethod method must be demoted out of the native layout"
    );
}

# `class def` sets `is_classmethod` rather than populating `decorators`, so
# it clears the capability gate, and codegen lowers it receiver-less like a
# static (a body that reads `cls` demotes through normal name resolution).
# The behavioral pin lives in the block above (`call_classmethod`).
