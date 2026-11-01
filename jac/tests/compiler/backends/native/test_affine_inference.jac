"""Droppless affine inference for unannotated locals (#7857 Phase E).

A LOCAL binding with no ownership annotation whose object never escapes --
scalar field reads under calls and returns included -- allocates on the
stack in managed modes too, because for a type with no `drop` hook the
reclamation point is unobservable. Types with a `drop` hook are excluded
by the decision step, so hook timing never changes. Zero user action.

The decision shows in the function's MIR: a stack-promoted local never
calls its archetype's heap constructor (`<Archetype>.__ctor`).
"""

import os;
import from tests.support { TESTS_DIR, KernelFixture, compile_mir }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "affine_inference.jac"
     );

"""The MIR text of `name`'s function in a compiled fixture."""
def mir_function(fx: KernelFixture, name: str) -> str {
    head = f"fn @{fx.symbol(name)}(";
    for chunk in fx.mir().split("\n\n") {
        if chunk.startswith(head) {
            return chunk;
        }
    }
    raise AssertionError(f"no MIR function {name} in {fx.path}: demoted {fx.demoted()}");
}

def _compile -> KernelFixture {
    return compile_mir(
        FIXTURE,
        "",
        CompileOptions(
            force_codespace="native",
            aot_mode=True,
            native_target="wasm32-unknown-unknown"
        )
    );
}

test "unannotated droppless local with call-position scalar reads is promoted" {
    fx = _compile();
    body = mir_function(fx, "scalar_reads");
    assert f"@{fx.symbol('Point.__ctor')}" not in body , body;
}

test "a type with a drop hook is never inference-promoted" {
    fx = _compile();
    body = mir_function(fx, "hooked");
    assert f"@{fx.symbol('Loud.__ctor')}" in body , body;
}
