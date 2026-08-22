"""Codegen contract: client `has` state is read-your-writes on every backend.

The language rule (see docs: client state semantics): assignment to a `has`
field is immediately visible to every later read -- same ability, helper
method, lambda, async continuation. Solid delivers this natively via
signal getters; the React-family backends deliver it by lowering state to a
per-field store cell (`useJacState`) whose reads (`.val`) and writes
(`.set(...)`) hit current values synchronously, with rendering subscribed
via useSyncExternalStore.

These tests pin the emitted shape for the react and preact backends:
  - state fields lower to `const __jacS_<name> = useJacState(<init>)`
  - reads lower to `__jacS_<name>.val`
  - writes lower to `__jacS_<name>.set(<expr>)`
  - augmented writes read the CURRENT value: `.set(__jacS_n.val + 1)`
  - dependency effects sample values: `[__jacS_n.val]`
  - `useJacState` imports from `@jac/runtime` on both backends
  - no `useState` state lowering remains
  - the setter name `set<Name>` is a real binding, not only a rewrite of the
    write sites the backend happens to recognize (#8224)
"""

import os;
import re;
import from tests.support { JAC_ROOT }
import from jaclang.compiler.passes.ecmascript { EsastGenPass }
import from jaclang.compiler.passes.ecmascript.backends.preact { PreactBackend }
import from jaclang.compiler.passes.ecmascript.backends.react { ReactBackend }
import from jaclang.compiler.passes.ecmascript.es_unparse { es_to_js }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compiler { run_pass }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "ecmascript", "fixtures"
     );

def compile_with_backend(fixture_name: str, backend: object) -> str {
    prog = JacProgram();
    ir = prog.compile(file_path=os.path.join(FIXTURES, fixture_name), no_cgen=True);
    assert not prog.errors_had , (
        f"Compilation errors in {fixture_name}: {[str(e) for e in prog.errors_had]}"
    );
    es_pass = run_pass(EsastGenPass, ir, prog, backend=backend);
    return es_to_js(es_pass.ir_out.gen.es_ast);
}

def assert_store_contract(js: str, backend_name: str) {
    # State fields lower through the store hook, not useState.
    assert re.search(r"const __jacS_flag = useJacState\(", js) , (
        f"[{backend_name}] state field must lower to a __jacS_ cell via "
        f"useJacState:\n{js}"
    );
    assert "useState(" not in js , (
        f"[{backend_name}] no useState state lowering may remain:\n{js}"
    );

    # Reads go through the cell's current value.
    assert "__jacS_label.val" in js , (
        f"[{backend_name}] state reads must lower to __jacS_<name>.val:\n{js}"
    );

    # Writes go through the cell's setter.
    assert "__jacS_label.set(" in js , (
        f"[{backend_name}] state writes must lower to __jacS_<name>.set(:\n{js}"
    );

    # Augmented writes read the CURRENT value, killing the stale
    # double-toggle (`n += 1; n += 1;` nets +2, not +1).
    assert re.search(r"__jacS_n\.set\(\(?\s*__jacS_n\.val\s*\+\s*1\s*\)?\)", js) , (
        f"[{backend_name}] augmented writes must read the current cell " f"value:\n{js}"
    );

    # Dependency effects sample values at render.
    assert re.search(r"\[\s*__jacS_n\.val\s*\]", js) , (
        f"[{backend_name}] effect deps must sample __jacS_<name>.val:\n{js}"
    );

    # The store hook resolves from @jac/runtime on every React-family
    # backend (never preact/hooks).
    assert re.search(r'import \{[^}]*useJacState[^}]*\} from "@jac/runtime"', js) , (
        f"[{backend_name}] useJacState must import from @jac/runtime:\n{js}"
    );
}

"""Pin the setter binding: `set<Name>` must be declared, not just rewritten.

The store-cell migration kept every write SITE working by rewriting it to
`__jacS_x.set(...)`, but a setter used as a value has no site to rewrite. It
reaches codegen as a plain identifier, so the module has to declare the name.
"""
def assert_setter_binding(js: str, backend_name: str) {
    decl = re.search(r"\bconst\s+setTheme\s*=\s*([^;,\n]+)", js);
    assert decl is not None , (
        f"[{backend_name}] `has theme` must bind `setTheme` as a real value; "
        f"the emitted module never declares it:\n{js}"
    );
    assert "__jacS_theme" in decl.group(1) , (
        f"[{backend_name}] `setTheme` must delegate to the state cell's "
        f"setter, got `{decl.group(1).strip()}`:\n{js}"
    );

    # The value reference itself stays an ordinary reference.
    assert "setTheme: setTheme" in js , (
        f"[{backend_name}] the setter reference must emit as a plain "
        f"identifier:\n{js}"
    );
}

"""Pin the other half of the same failure: a state read in shorthand position.

JSX attribute shorthand parses one Name into both the attribute's name and its
value. Treating that node as a name-only slot skipped the state read rewrite,
so the value emitted as a bare identifier the module never binds.
"""
def assert_shorthand_read(js: str, backend_name: str) {
    assert '"flag": __jacS_flag.val' in js , (
        f"[{backend_name}] a shorthand JSX attribute must lower its value as "
        f"a state read:\n{js}"
    );
    assert re.search(r"\{\s*[\"']?flag[\"']?\s*:\s*flag\s*\}", js) is None , (
        f"[{backend_name}] the shorthand value must not stay a bare "
        f"identifier:\n{js}"
    );
}

test "react backend lowers has state to read-your-writes store cells" {
    js = compile_with_backend("state_semantics_component.jac", ReactBackend());
    assert_store_contract(js, "react");
}

test "preact backend inherits the store cell lowering" {
    js = compile_with_backend("state_semantics_component.jac", PreactBackend());
    assert_store_contract(js, "preact");
}

test "react binds the state setter as a first-class value" {
    js = compile_with_backend("state_setter_value_ref.jac", ReactBackend());
    assert_setter_binding(js, "react");
}

test "preact binds the state setter as a first-class value" {
    js = compile_with_backend("state_setter_value_ref.jac", PreactBackend());
    assert_setter_binding(js, "preact");
}

test "react lowers a shorthand jsx attribute as a state read" {
    js = compile_with_backend("state_shorthand_attr.jac", ReactBackend());
    assert_shorthand_read(js, "react");
}

test "preact lowers a shorthand jsx attribute as a state read" {
    js = compile_with_backend("state_shorthand_attr.jac", PreactBackend());
    assert_shorthand_read(js, "preact");
}
