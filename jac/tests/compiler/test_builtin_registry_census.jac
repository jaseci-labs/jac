"""Pins the three ambient-builtin registries to each other.

An ambient builtin is declared three times by design:

  - `jaclang/runtimelib/builtin.jac` carries the runtime behaviour, and its
    `__all__` is what the module actually exports.
  - `jaclang/jac0core/jcir_facts.jac` carries `JCIR_BUILTIN_NAMES`, the set
    `JcirGenPass` matches every `Name` against to decide whether to synthesize
    `from jaclang.runtimelib.builtin import <name>` into the module preamble.
  - `jaclang/compiler/type_system/jac_builtins.pyi` carries the signatures the
    type checker merges into `builtins_module`.

Nothing connected them, so they drifted twice. Against the stub: `managed`,
`jref`, `JacListView` and the four `schema_*` builders shipped as working
runtime builtins that the checker reported as `W2001: Name may be undefined`,
which then cascaded into `Unknown` types at every call site. Against the
codegen set: `testskip`/`testfail`/`testraises`/`RaisesContext` landed in
`__all__` and in the stub but not in `JCIR_BUILTIN_NAMES`, so no import was ever
emitted and every call site that actually reached one died at runtime with
`NameError` -- invisibly, because they sit on skip paths that only fire when a
gate closes.

These tests fail the moment a name is added to one registry and not the others.
"""

import ast;
import os;
import re;

import from jaclang.jac0core.jcir_facts { JCIR_BUILTIN_NAMES }
import from tests.support { JAC_ROOT }

glob _PYI_PATH: str = os.path.join(
         JAC_ROOT, "jaclang", "compiler", "type_system", "jac_builtins.pyi"
     ),
     _BUILTIN_PATH: str = os.path.join(
         JAC_ROOT, "jaclang", "runtimelib", "builtin.jac"
     );


"""Names exported by the checker-side stub, and names it actually declares."""
def _pyi_surface -> tuple[set[str], set[str]] {
    with open(_PYI_PATH, encoding="utf-8") as f {
        tree = ast.parse(f.read());
    }
    exported: set[str] = set();
    declared: set[str] = set();
    for node in tree.body {
        if isinstance(node, ast.Assign) {
            for target in node.targets {
                if isinstance(target, ast.Name) and (target.id == "__all__") {
                    for elt in node.value.elts {
                        exported.add(elt.value);
                    }
                }
            }
        }
        if isinstance(node, (ast.FunctionDef, ast.ClassDef)) {
            declared.add(node.name);
        }
        if isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name) {
            declared.add(node.target.id);
        }
        if isinstance(node, ast.Assign) {
            for target in node.targets {
                if isinstance(target, ast.Name) {
                    declared.add(target.id);
                }
            }
        }
    }
    return (exported, declared);
}


"""Public names in the runtime module's `__all__` (underscore names are internal
codegen helpers that the checker never resolves by name)."""
def _runtime_public_names -> set[str] {
    import jaclang.runtimelib.builtin as builtin_mod;
    return {
        name
        for name in builtin_mod.__all__
        if not name.startswith("_")
    };
}


test "every runtime ambient builtin is exported by the checker stub" {
    (exported, _declared) = _pyi_surface();
    missing = sorted(_runtime_public_names() - exported);
    assert not missing , (
        f"in builtin.__all__ but not jac_builtins.pyi __all__: {missing}. "
        "Codegen will emit an import for these while the checker reports "
        "W2001 and infers Unknown at every call site."
    );
}


test "the checker stub declares everything it exports" {
    (exported, declared) = _pyi_surface();
    missing = sorted(exported - declared);
    assert not missing , (
        f"listed in jac_builtins.pyi __all__ but never declared there: {missing}"
    );
}


"""The runtime `__all__` is parsed out of source here rather than imported, so a
malformed literal is caught as a test failure instead of an import crash."""
test "builtin.jac __all__ parses and matches the imported module" {
    with open(_BUILTIN_PATH, encoding="utf-8") as f {
        source = f.read();
    }
    block = re.search(r"glob __all__ = \[(.*?)\];", source, re.S);
    assert block is not None , "could not find `glob __all__` in builtin.jac";
    from_source = set(re.findall(r"'([^']+)'", block.group(1)));
    import jaclang.runtimelib.builtin as builtin_mod;
    assert from_source == set(builtin_mod.__all__);
}


"""The codegen set is what makes a name ambient at all: a name outside it is
never imported into the module preamble, so it reaches the interpreter as a bare
global and raises `NameError` the first time control flows through it."""
test "the codegen builtin set is exactly the runtime module's __all__" {
    import jaclang.runtimelib.builtin as builtin_mod;
    codegen = set(JCIR_BUILTIN_NAMES);
    runtime = set(builtin_mod.__all__);
    unimported = sorted(runtime - codegen);
    assert not unimported , (
        f"in builtin.__all__ but not JCIR_BUILTIN_NAMES: {unimported}. "
        "JcirGenPass emits no import for these, so every call site raises "
        "NameError at runtime."
    );
    unbacked = sorted(codegen - runtime);
    assert not unbacked , (
        f"in JCIR_BUILTIN_NAMES but not builtin.__all__: {unbacked}. "
        "JcirGenPass will emit an import that fails at module load."
    );
}


test "the test builtins are ambient in every registry" {
    (exported, declared) = _pyi_surface();
    runtime = _runtime_public_names();
    codegen = set(JCIR_BUILTIN_NAMES);
    for name in ("testskip", "testfail", "testraises", "RaisesContext") {
        assert name in runtime , f"{name} missing from builtin.__all__";
        assert name in codegen , f"{name} missing from JCIR_BUILTIN_NAMES";
        assert name in exported , f"{name} missing from jac_builtins.pyi __all__";
        assert name in declared , f"{name} not declared in jac_builtins.pyi";
    }
}
