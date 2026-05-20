"""`try { ... } awaiting { ... }` inside a JSX slot.

An `awaiting` clause inside a `try` shifts the slot's rendering model:
the awaiting body renders while the try body's async work is in flight,
the try body's resolved content renders once the work settles. On the
`cl` target this lowers to `<JacAwaiting fallback={...}>{...}</JacAwaiting>` —
a thin wrapper over `React.Suspense` exported by `@jac/runtime`.

This fixture exercises the parser + AST + view-lowering path end-to-end
on the `cl` target: `awaiting` is a clause keyword on `try`, the lowered
output references `JacAwaiting` (auto-imported from the runtime), and
both branch bodies survive as inline IIFE fragments.
"""

obj UserCard {
    has name: str,
        bio: str;
}

"""Loading shell shown while the user-card data is in flight."""
def:pub UserCardSkeleton -> JsxElement {
    return
        <div class="card skeleton">
            <p>Loading user…</p>
        </div>;
}

"""Renders the resolved card.  In a real app the data fetch happens
inside this component (e.g. via a Suspense-aware `use()` call) so the
ancestor `awaiting` clause's fallback is what shows during the load."""
def:pub UserCardView(user: UserCard) -> JsxElement {
    return
        <div class="card">
            <h2>{user.name}</h2>
            <p>{user.bio}</p>
        </div>;
}

"""Component using a slot-level `try { ... } awaiting { ... }`.

The slot wraps the resolved-state JSX in an `awaiting` window — while
the underlying fetch is unresolved the `awaiting` body renders;
afterwards the `try` body's content takes over. The compile-time
lowering wraps the whole construct in `<JacAwaiting>` and the runtime
ties the wrapper to `React.Suspense`."""
def:pub UserPanel(user: UserCard) -> JsxElement {
    return
        <section class="panel">
            <header>User</header>
            {try {
                <UserCardView user={user}/>
            } awaiting {
                <UserCardSkeleton/>
            }}
            <footer>End</footer>
        </section>;
}
