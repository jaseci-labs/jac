"""Fixture #5 (contract §7) — block/scope shadowing of a reactive field.

KNOWN LIMITATION (contract §4.3): `reactive_vars` is tracked per-ability — a
copy-on-enter at the function boundary (`enter_ability`), not per lexical block.
A nested binding that shadows a reactive `has` field — here the `count` parameter
of `formatted` — is still treated as reactive, so its read lowers through
`lower_state_read`. On Solid this wrongly emits `count()` for what is actually a
plain local parameter; the outer field read is correctly reactive.

Do NOT "fix" the asserted output for this fixture without first landing contract
§4.3 Option B (block-scoped tracking) or Option C (symbol-table def-use). The
acceptance matrix test pins the CURRENT (wrong-on-Solid) output on purpose.
"""

def:pub shadow_app() -> JsxElement {
    has count: int = 0;

    def formatted(count: int) -> JsxElement {
        # `count` here is the parameter — a genuine local shadowing the field.
        # Per-ability tracking still considers it reactive (the bug we pin).
        return <span>{count}</span>;
    }

    return <div>
        <p>Field: {count}</p>
        {formatted(99)}
    </div>;
}
