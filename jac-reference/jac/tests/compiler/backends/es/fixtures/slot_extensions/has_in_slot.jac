"""Rec 3 — `has`-field declared inside a JSX slot body.

A `has`-field inside a slot's statement template would compile to a
conditional/looped `useState` invocation — a rules-of-hooks violation.
ViewLowerPass's `_check_body` should recurse into slot bodies and emit
E2023 on any `uni.HasVar` it finds.

Component state must be declared at the enclosing component scope (the
`def -> JsxElement` body), not at slot-template positions.
"""

def:pub BadSlotState(active: bool) -> JsxElement {
    return
        <div>
            {if active {
                has count: int = 0;
                <p>Count: {count}</p>
            }}
        </div>;
}
