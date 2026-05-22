"""Rec 6 — statement-level JSX in a `def -> JsxElement` body.

In client context, a `def -> JsxElement` body that contains top-level
JSX `ExprStmt`s without an explicit `return <jsx>;` should be treated as
an implicit outer slot — the same accumulator-IIFE lowering as a
statement slot body, just at function scope.

Today this fixture either fails to compile or compiles to a function
that returns `undefined` (the JSX statements are evaluated for side
effects and discarded). The expected behaviour is that the function
returns the accumulated `<>{children}</>` fragment.
"""

def:pub Greeting(name: str) -> JsxElement {
    <h1>Hello, {name}</h1>
    if name == "admin" {
        <p>Hello, admin</p>
    }
}
