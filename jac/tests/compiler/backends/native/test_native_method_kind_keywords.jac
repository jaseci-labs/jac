"""Method-kind keywords lower natively; the Python decorator spellings do not.

Jac has first-class syntax for all three method kinds -- `abst`, `class def`,
`static def` -- which the parser turns into `uni.Ability` flags
(`is_abstract` / `is_classmethod` / `is_static`) and `pyast_gen` re-emits as
`@abstractmethod` / `@classmethod` / `@staticmethod` on the Python backend.

The native capability authority inspects `nd.decorators`, a list of `Expr`
nodes. A keyword populates no such list, so the keyword forms cross the
native boundary while the hand-written decorators demote their method to a
Python-only seam (granular demotion, epic #8201) -- the method is demoted
off native rather than running undecorated. The compiler's own front-end
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
import from pathlib { Path }
import from tests.support {
    compile_mir,
    compile_native,
    diagnostics_text,
    fixture_path,
    get_func,
    has_error_code,
    kernel_check_source,
    kernel_compile_file,
    kernel_compile_source,
    native_force_opts,
    source_spelled,
    write_case
}
import from jaclang.compiler.driver.compile_options { CompileOptions }

"""Run a snippet through the check entry with the native capability authority
on -- the `jac check` path that surfaces E5090."""
def check_na_inline(label: str, code: str) -> any {
    return kernel_check_source(
        code, f"mkind_{label}.jac", CompileOptions(force_codespace="native")
    );
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
    result = kernel_compile_file(
        fixture_path("method_kind_keywords.jac"), native_force_opts()
    );
    assert result.ok() , diagnostics_text(result);
}

# ─────────────────────────────────────────────────────────────────────
# The decorator spellings demote off native -- this is why the sources moved
# ─────────────────────────────────────────────────────────────────────

test "guardrail: @abstractmethod refuses where abst is accepted" {
    result = kernel_compile_source(
        "import from abc { abstractmethod }\n"
        "obj Base {\n"
        "    @abstractmethod\n"
        "    def go(x: int) -> int;\n"
        "}\n"
        "obj Impl(Base) {\n"
        "    def go(x: int) -> int { return x + 1; }\n"
        "}\n"
        "with entry { print(Impl().go(1)); }\n",
        "mkind_abstractmethod.jac",
        native_force_opts()
    );
    errs = diagnostics_text(result);
    assert "decorator 'on go'" in errs , (
        f"the capability gate must still name the decorator spelling: {errs}"
    );
    assert "Python module import 'abc'" in errs , (
        "the decorator cannot be written without importing it, and a "
        "module-scope Python import has no owning callable to absorb it as "
        "a seam. `import abc;` has always refused the whole module here; "
        f"the `from` spelling is classified on the same terms: {errs}"
    );
    assert not any(unit.native_ir for unit in result.units) , (
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
    assert kw.ok() , diagnostics_text(kw);
}

test "guardrail: @classmethod demotes at the capability gate" {
    path = Path(
        write_case(
            "obj Holder {\n"
            "    @classmethod\n"
            "    def make(cls: any) -> int { return 7; }\n"
            "}\n",
            "mkind_classmethod.jac"
        )
    );
    fx = compile_mir(path.name, str(path.parent));
    assert not has_error_code(fx.result, "E5090") , (
        f"a @classmethod method must demote, not fail the module: "
        f"{diagnostics_text(fx.result)}"
    );
    assert any(source_spelled(sym).endswith(".Holder.make") for sym in fx.demoted()) , (
        f"the @classmethod method must be demoted out of native: {fx.demoted()}"
    );
}

# `class def` sets `is_classmethod` rather than populating `decorators`, so
# it clears the capability gate, and codegen lowers it receiver-less like a
# static (a body that reads `cls` demotes through normal name resolution).
# The behavioral pin lives in the block above (`call_classmethod`).
