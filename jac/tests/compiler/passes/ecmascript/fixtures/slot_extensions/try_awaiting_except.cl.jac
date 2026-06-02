"""Rec 2 — `try` slot carrying both `awaiting` AND `except` clauses.

Today the `awaiting` clause lowers to `<JacAwaiting fallback={...}>...`
but the `except` arm is silently parsed and never wired through the
runtime wrapper. The expected behavior: synthesize a
`<JacClientErrorBoundary fallback={<>...except body...</>}>`
around the existing `<JacAwaiting>` so both the loading and error states
are first-class on the `cl` target.
"""

obj User {
    has name: str,
        bio: str;
}

def:pub UserCard(user: User) -> JsxElement {
    return
        <div class="card">
            <h2>{user.name}</h2>
            <p>{user.bio}</p>
        </div>;
}

def:pub UserPanel(user: User) -> JsxElement {
    return
        <section class="panel">
            {try {
                <UserCard user={user}/>
            } awaiting {
                <p>Loading…</p>
            } except Exception {
                <p>Something went wrong</p>
            }}
        </section>;
}
