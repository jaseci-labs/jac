"""Rec 2 (dedupe guard) — keyless `for` inside the except arm of a
slot `try`/`awaiting`/`except`.

The except body is a sub-body that `exit_jsx_slot`'s top-level
`_check_body` recursion already validates. The synthetic-slot lowering
that builds the error-boundary fallback must NOT re-run `_check_body`,
or the keyless-for W2021 would be emitted twice for the same span.
"""

obj User {
    has name: str;
}

def:pub UserPanel(users: list[User]) -> JsxElement {
    return
        <section class="panel">
            {try {
                <p>ok</p>
            } awaiting {
                <p>Loading…</p>
            } except Exception {
                for u in users {
                    <li>{u.name}</li>
                }
            }}
        </section>;
}
