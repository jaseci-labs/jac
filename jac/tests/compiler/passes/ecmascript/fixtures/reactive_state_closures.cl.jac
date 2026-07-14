"""Fixture: reactive `has` writes inside nested / deferred closures (issue #6459).

A reactive `has` assignment must be rewritten to its state setter at any closure
depth - directly in an event handler, inside a `setTimeout` callback, and inside
an immediately-invoked nested lambda. Regression guard: these must all become
`setX(...)`, not bare `x = ...`.
"""

cl {
    def:pub closures_app() -> JsxElement {
        has seen: bool = False;
        has armed: bool = False;
        has fired: bool = False;

        return <div>
            <button onClick={lambda (e: any) { seen = True; }}>direct</button>
            <button onClick={lambda (e: any) { setTimeout(lambda { armed = True; }, 0); }}>
                deferred
            </button>
            <button onClick={lambda (e: any) { (lambda { fired = True; })(); }}>
                nested
            </button>
        </div>;
    }
}
