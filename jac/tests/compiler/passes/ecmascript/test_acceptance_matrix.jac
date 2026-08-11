"""Phase 4 — authoritative §7 cross-backend acceptance matrix.

This file is the single authoritative regression gate for the framework-agnostic
client codegen seam (issue 6490). The contract's §7 acceptance fixtures each
*arrive* with their phase (P1 read seam, P2 view seam, P3 SolidBackend), but
their pass criteria are pinned here as one cross-backend matrix so a regression
in any single backend is caught against the same fixtures.

Matrix (contract §7 / `_planning/reactivity-implementation-plan.md` Phase 4):

  # | Fixture                       | Pass criteria
  --+-------------------------------+------------------------------------------------
  1 | reactive_state_client.jac         | Solid `count()` read / `setCount` write; React `count`
  2 | reactive_effects_deps.jac     | Compiles; React keeps dep array, Solid omits it
  3 | view_awaiting.jac          | React `JacAwaiting`; Solid `Suspense`
  4 | reactive_view_audit.jac    | Dynamic `{count}` routes via `lower_view_expr`
  5 | reactive_shadow.jac        | KNOWN LIMITATION — pins current wrong-on-Solid output
  6 | reactive_view_audit.jac    | `onClick` handler never view-wrapped
  7 | slot_extensions/has_ref.jac| React `useRef`; Solid deferred to a `let` binding

Two invariants this matrix protects:
  * React/Preact output is byte-identical to pre-seam (the zero-diff gate). The
    read/view seams are identity no-ops on those backends.
  * Documented limitations are *pinned*, not faked: fixture #5 asserts the
    current (incorrect-on-Solid) output on purpose, so a future fix (contract
    §4.3 Option B/C) must update this test deliberately.
"""

import os;
import from tests.support { JAC_ROOT }
import jaclang;
import from jaclang.compiler.passes.ecmascript { EsastGenPass }
import from jaclang.compiler.passes.ecmascript.backends.react { ReactBackend }
import from jaclang.compiler.passes.ecmascript.backends.preact { PreactBackend }
import from jaclang.compiler.passes.ecmascript.backends.solid { SolidBackend }
import from jaclang.compiler.passes.ecmascript.es_unparse { es_to_js }
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "ecmascript", "fixtures"
     );

"""Compile a fixture with the given backend and return emitted JS."""
def compile_fixture_with_backend(fixture_name: str, backend: object) -> str {
    prog = JacProgram();
    ir = prog.compile(file_path=os.path.join(FIXTURES, fixture_name), no_cgen=True);
    assert not prog.errors_had , (
        f"Compilation errors in {fixture_name}: {[str(e) for e in prog.errors_had]}"
    );
    es_pass = EsastGenPass(ir_in=ir, prog=prog, backend=backend);
    return es_to_js(es_pass.ir_out.gen.es_ast);
}

# --- #1 Counter read/write -----------------------------------------------------
test "matrix #1 react: store cell read, cell setter write" {
    js = compile_fixture_with_backend("reactive_state_client.jac", ReactBackend());
    assert "const __jacS_count = useJacState(0)" in js;
    assert "__jacS_count.set(42)" in js;
    # React reads are synchronous cell reads, never accessor calls.
    assert "__jacS_count.val" in js;
    assert "count()" not in js;
    assert "createSignal" not in js;
    assert "useState" not in js;
}

test "matrix #1 solid: accessor read, setCount write, createSignal state" {
    js = compile_fixture_with_backend("reactive_state_client.jac", SolidBackend());
    assert "const [count, setCount] = createSignal(0)" in js;
    assert "setCount(42)" in js;
    assert 'setName("hello")' in js;
    # Reads become bare accessor calls in `{…}` (un-thunked: the dom-expressions
    # compiler tracks them); writes stay setter calls.
    assert "{count()}" in js;
    assert "() => count()" not in js , "JSX path must not thunk reactive reads";
    assert "useState" not in js;
}

# --- #2 Effect with deps -------------------------------------------------------
test "matrix #2 react: useEffect keeps an explicit dep array" {
    js = compile_fixture_with_backend("reactive_effects_deps.jac", ReactBackend());
    assert "useEffect(" in js;
    # `userId` is a prop (stays bare); `loading` is state (samples the cell).
    assert "[userId, __jacS_loading.val]" in js , (
        "React effect must keep its dep array, sampling state cell values"
    );
    assert "createEffect" not in js;
}

test "matrix #2 solid: createEffect auto-tracks and omits the dep array" {
    js = compile_fixture_with_backend("reactive_effects_deps.jac", SolidBackend());
    assert "createEffect(" in js;
    assert "useEffect" not in js;
    # Solid auto-tracks — no React-style dependency array is emitted.
    assert "[userId, loading]" not in js;
    # Reactive reads inside the view are un-thunked accessor calls in `{…}`.
    assert "{loading()}" in js;
}

# --- #3 awaiting try -----------------------------------------------------------
test "matrix #3 react: awaiting lowers to the JacAwaiting Suspense shim" {
    js = compile_fixture_with_backend("view_awaiting.jac", ReactBackend());
    assert "JacAwaiting" in js;
    assert "Suspense" not in js , "React uses the JacAwaiting shim, not raw Suspense";
}

test "matrix #3 solid: awaiting lowers to Solid Suspense, never the React shim" {
    js = compile_fixture_with_backend("view_awaiting.jac", SolidBackend());
    assert "Suspense" in js;
    assert "JacAwaiting" not in js , "Solid must not emit the React Suspense shim";
}

# --- #4 Dynamic {count} / #6 onClick handler -----------------------------------
test "matrix #4/#6 react: dynamic positions and handler are plain (seam no-op)" {
    js = compile_fixture_with_backend("reactive_view_audit.jac", ReactBackend());
    # Read seam lowers to a synchronous cell read; the view seam stays
    # identity on React — no Solid-style accessor thunks. (The `onClick`
    # lambda is still an arrow function — the handler itself, not a view
    # thunk.)
    assert '"value": __jacS_count.val' in js;
    assert "count()" not in js , "React must not thunk dynamic positions";
    assert '"type": "text"' in js;
    assert '"onClick":' in js;
}

test "matrix #4/#6 solid: dynamic positions un-thunked, handler never view-wrapped" {
    js = compile_fixture_with_backend("reactive_view_audit.jac", SolidBackend());
    # #4 — dynamic attribute value and dynamic child are bare `{expr}`; the
    # dom-expressions compiler tracks reactivity, so the `() =>` thunk is gone.
    assert "value={count()}" in js , "dynamic attribute value should be un-thunked";
    assert "value={() => count()}" not in js;
    assert "{count()}" in js , "dynamic child should be un-thunked";
    # Static literal attribute stays a plain string attribute.
    assert 'type="text"' in js;
    # #6: the event handler is emitted as-is. The authored lambda's implicit
    # return compiles to `() => count()`; a view wrap would add a second arrow.
    assert "onClick={() => count()}" in js , "handler should be emitted as-is";
    assert "onClick={() => () =>" not in js , "handler must not be view-wrapped";
}

# --- #5 Block / scope shadowing — KNOWN LIMITATION -----------------------------
test "matrix #5 react: shadowing param is WRONGLY treated as reactive (pinned bug)" {
    js = compile_fixture_with_backend("reactive_shadow.jac", ReactBackend());
    # Same §4.3 known limitation as Solid, now uniform across backends: the
    # shadowing `count` parameter still lowers through `lower_state_read`,
    # so the nested read hits the outer cell instead of the local param.
    # Under the old bare-identifier lowering React happened to be correct
    # here; the store lowering makes the limitation visible. Do NOT "fix"
    # this pin without landing contract §4.3 (block-scoped tracking).
    assert "const __jacS_count = useJacState(0)" in js;
    assert 'return __jacJsx("span", {}, [__jacS_count.val])' in js;
    assert "count()" not in js;
}

test "matrix #5 solid: shadowing param is WRONGLY treated as reactive (pinned bug)" {
    js = compile_fixture_with_backend("reactive_shadow.jac", SolidBackend());
    # The outer field read is correctly reactive (un-thunked `{count()}` in JSX).
    assert "const [count, setCount] = createSignal(0)" in js;
    assert '{"Field: "}{count()}' in js , "outer field read is correctly reactive";
    # KNOWN LIMITATION (contract §4.3): `reactive_vars` is per-ability, so the
    # `count` PARAMETER of `formatted` is still treated as reactive and its read
    # lowers to `count()` — it SHOULD be the plain local parameter. We pin this
    # wrong output on purpose. Fixing it requires §4.3 Option B/C; that work must
    # update this assertion deliberately.
    assert "return <span>{count()}</span>" in js , (
        "fixture #5 pins the current per-ability shadowing limitation"
    );
}

# --- #7 has r: Ref[T] ----------------------------------------------------------
test "matrix #7 react: Ref[T] field lowers to useRef" {
    js = compile_fixture_with_backend("slot_extensions/has_ref.jac", ReactBackend());
    assert "useRef" in js;
    assert "buttonRef" in js;
    assert "createSignal" not in js;
}

test "matrix #7 solid: Ref[T] field is deferred to a plain let binding" {
    js = compile_fixture_with_backend("slot_extensions/has_ref.jac", SolidBackend());
    # Refs are deferred on Solid (contract §8) — no useRef, no signal.
    assert "let buttonRef = null" in js , "Solid defers refs to a let binding";
    assert "useRef" not in js;
    assert "createSignal(null)" not in js;
    # The `ref={buttonRef}` JSX attribute must NOT be thunked: Solid calls a ref
    # callback with the DOM node (Phase 0 spike confirmed a member/identifier ref
    # registers), so a `() => buttonRef` wrapper would swallow the element and the
    # node would never register (TODO #1 regression guard).
    assert "ref={buttonRef}" in js , "ref attribute must escape the view thunk seam";
    assert "ref={() => buttonRef}" not in js , "ref must never be view-wrapped";
}

# --- Zero-diff gate: Preact tracks React on the seam-sensitive fixtures ---------
test "matrix zero-diff: preact view output matches react (seams are no-ops)" {
    react_js = compile_fixture_with_backend("reactive_view_audit.jac", ReactBackend());
    preact_js = compile_fixture_with_backend(
        "reactive_view_audit.jac", PreactBackend()
    );
    # Preact differs only in import sources; the read/view seams are identity on
    # both, so the component body (JSX + reads) must be byte-identical.
    react_body = react_js.split("function View_app")[1];
    preact_body = preact_js.split("function View_app")[1];
    assert react_body == preact_body , (
        "Preact body must be byte-identical to React (seam no-op invariant)"
    );
}
