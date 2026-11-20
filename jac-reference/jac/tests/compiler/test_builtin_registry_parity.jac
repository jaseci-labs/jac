"""Pins the three ambient-builtin registries to each other.

An ambient builtin is declared three times by design:
`jaclang/runtime/builtin.jac` carries the runtime behaviour and its
`__all__` is the public list; `jaclang/compiler/types/jac_builtins.pyi`
carries the signatures the type checker merges into `builtins_module`; and
`JCIR_BUILTIN_NAMES` in `compiler/backends/py/jcir_facts.jac` is what the emitter reads to
decide which bare names become `from jaclang.runtime.builtin import <name>`
in the emitted preamble.

Nothing connected them, so they drifted, twice. The runtime-versus-checker
drift shipped `managed`, `jref`, `JacListView` and the four `schema_*`
builders as working builtins the checker reported as `W2001: Name may be
undefined`, cascading into `Unknown` at every call site. The
runtime-versus-emitter drift arrived with the compact codegen IR: `testskip`,
`testfail`, `testraises` and `RaisesContext` were in `__all__` and in the
stub and not in the emitter's list, so every test that used one compiled
clean and raised `NameError` when it ran.

These tests fail the moment a name is added to one registry and not the
others.
"""

import ast;
import os;
import re;

import from jaclang.compiler.backends.py.jcir_facts { JCIR_BUILTIN_NAMES }
import from tests.support { JAC_ROOT }

glob _PYI_PATH: str = os.path.join(
         JAC_ROOT, "jaclang", "compiler", "types", "jac_builtins.pyi"
     ),
     _BUILTIN_PATH: str = os.path.join(JAC_ROOT, "jaclang", "runtime", "builtin.jac");


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
                    # The stub types `node.value` as the `expr` base; the
                    # __all__ literal is a List of Constants at runtime.
                    all_literal: any = node.value;
                    for elt in all_literal.elts {
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
    import jaclang.runtime.builtin as builtin_mod;
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
    import jaclang.runtime.builtin as builtin_mod;
    assert from_source == set(builtin_mod.__all__);
}


test "the test builtins are ambient in all three registries" {
    (exported, declared) = _pyi_surface();
    runtime = _runtime_public_names();
    for name in ("testskip", "testfail", "testraises", "RaisesContext") {
        assert name in runtime , f"{name} missing from builtin.__all__";
        assert name in exported , f"{name} missing from jac_builtins.pyi __all__";
        assert name in declared , f"{name} not declared in jac_builtins.pyi";
        assert name in JCIR_BUILTIN_NAMES , (
            f"{name} missing from JCIR_BUILTIN_NAMES, so the emitter never "
            "synthesizes its import and every test that uses it raises "
            "NameError at run time"
        );
    }
}


"""The emitter's registry is the one that decides what actually gets imported.

`JCIR_BUILTIN_NAMES` is the third copy of this list, read by
`JcirGenPass.exit_name` to decide which names become
`from jaclang.runtime.builtin import <name>` in the emitted preamble. It is
a literal rather than a read of `__all__` because the emitter is a sealed unit
and cannot import the runtime module, which is exactly the condition under
which two lists drift -- and they did: the four test builtins were in
`__all__` and in the stub and not here, so `testraises` compiled clean and
`NameError`d at run time.
"""
test "the emitter's builtin registry matches the runtime __all__" {
    runtime = _runtime_public_names();
    missing = sorted(runtime - set(JCIR_BUILTIN_NAMES));
    assert not missing , (
        f"in builtin.__all__ but not JCIR_BUILTIN_NAMES: {missing}. The "
        "emitter will not import these, so a module that uses one compiles "
        "clean and fails at run time."
    );
    emitter_only = set(JCIR_BUILTIN_NAMES) - runtime;
    extra = sorted(
        n
        for n in emitter_only
        if not n.startswith("_")
    );
    assert not extra , (
        f"in JCIR_BUILTIN_NAMES but not builtin.__all__: {extra}. The "
        "emitter would synthesize an import of a name the runtime module "
        "does not export."
    );
}
