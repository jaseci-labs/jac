"""A keyword-argument key is an identifier, not a scope reference (#8270).

`DeclImplMatchPass._resolve_symbols_in_subtree` resolves every unbound `Name`
against the scope chain. It guarded attribute names and nothing else, so a
keyword-argument key was handed the symbol of whatever unrelated local
happened to share its spelling. `jaclang/compiler/backends/native/elf_linker.jac`
carried 41 of those bindings, `align` among them: a local, a keyword key, and
a field name on both operands of the call the key sits in.

The reachable damage is the capture set. `UniScopeNode.get_enclosing_captures`
walks every `Name` and reads its symbol, so a nested function whose only
mention of an outer local is a keyword key captured it: the native emitter
gave `__jac_nested_slot_*` a capture parameter for a value its body never
reads, which is a phantom in the function's own ABI.

#8208 closed this class on the client lane with an identifier-slot predicate.
`is_identifier_slot` is that predicate, now shared: the front-end binder skips
those slots, the capture walk skips them, and the Python lane builds a keyword
key from its spelling rather than from a lowered reference.
"""

import ast as ast3;
import os;
import subprocess;
import sys;
import from tests.support { TESTS_DIR, native_force_opts }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = os.path.join(TESTS_DIR, "compiler", "passes", "fixtures");

"""Compile a fixture on the server lane and hand back the module."""
def compile_server(fixture: str) -> uni.Module {
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, fixture),
        options=CompileOptions(force_codespace='server')
    );
    assert ir is not None , f"no module for {fixture}";
    return ir;
}


def generated_python(fixture: str) -> str {
    return ast3.unparse(compile_server(fixture).gen.py_ast[0]);
}


def ability_named(ir: uni.Module, name: str) -> uni.Ability {
    for ab in ir.get_all_sub_nodes(uni.Ability) {
        if ab.name_ref is not None and ab.name_ref.sym_name == name {
            return ab;
        }
    }
    raise AssertionError(f"no ability named {name}");
}


test "a keyword-argument key carries no scope symbol" {
    ir = compile_server("kwarg_key_slot.jac");
    bound = [
        kw.key.sym_name
        for kw in ir.get_all_sub_nodes(uni.KWPair)
        if kw.key is not None and kw.key.sym is not None
    ];
    assert not bound , (f"keyword keys resolved against the scope chain: {bound}");
}


test "the predicate answers for both identifier slots" {
    ir = compile_server("kwarg_key_slot.jac");
    keys = [
        kw.key
        for kw in ir.get_all_sub_nodes(uni.KWPair)
        if kw.key is not None
    ];
    assert keys , "the fixture lost its keyword arguments";
    for k in keys {
        assert uni.is_identifier_slot(k) , f"keyword key {k.sym_name} read as a reference";
    }
    attrs = [
        tr.right
        for tr in ir.get_all_sub_nodes(uni.AtomTrailer)
        if tr.is_attr and isinstance(tr.right, uni.Name)
    ];
    assert attrs , "the fixture lost its attribute reads";
    for a in attrs {
        assert uni.is_identifier_slot(a) , f"attribute {a.sym_name} read as a reference";
    }
    locals_ = [
        nm
        for nm in ir.get_all_sub_nodes(uni.Name)
        if nm.sym_name == "total"
    ];
    assert locals_ , "the fixture lost its local";
    for nm in locals_ {
        assert not uni.is_identifier_slot(nm) , "a plain local read as an identifier slot";
    }
}


test "a nested function does not capture through a keyword key" {
    ir = compile_server("kwarg_key_slot.jac");
    caps = [s.sym_name for s in ability_named(ir, "slot").get_enclosing_captures()];
    assert "align" not in caps , (
        f"'align' is captured though `slot` only spells it as a keyword key: " f"{caps}"
    );
}


test "the native nested function takes no phantom capture" {
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, "kwarg_key_slot.jac"),
        options=native_force_opts()
    );
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    defs = [
        _l.strip()
        for _l in str(ir.gen.llvm_ir).split("\n")
        if "define" in _l and "__jac_nested_slot" in _l
    ];
    assert len(defs) == 1 , f"expected one nested definition, got {defs}";
    assert "cap.align" not in defs[0] , (
        f"the nested function carries a capture its body never reads: {defs[0]}"
    );
    assert defs[0].count(",") == 0 , (
        f"the nested function takes more than its declared parameter: {defs[0]}"
    );
}


test "the annexed body computes the same value on both lanes" {
    src = os.path.join(FIXTURES, "kwarg_key_slot.jac");
    sv = subprocess.run(
        [sys.executable, "-m", "jaclang", "run", src],
        capture_output=True,
        text=True,
        timeout=900
    );
    assert sv.returncode == 0 , f"server run failed: {sv.stderr[-800:]}";
    assert sv.stdout.strip() == "34" , f"server lane printed {sv.stdout!r}";
}


test "a keyword key spelled like a builtin pulls no import" {
    src = generated_python("kwarg_key_builtin.jac");
    assert "import store" not in src , (
        f"a keyword key minted a module-level import:\n{src}"
    );
}


test "a real reference to the same name still pulls its import" {
    src = generated_python("kwarg_key_builtin_ref.jac");
    assert "import store" in src , (
        f"the reference slot lost its import, so the guard is too wide:\n{src}"
    );
}
