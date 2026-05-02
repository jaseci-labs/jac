"""Test fixture for the W3041 stale-`has`-read diagnostic.

This is the textbook React stale-closure bug, surfaced through Jac:
inside `can with entry` (in client codespace), assigning to a `has`
field schedules a useState setter call for the next render. Reading
the same field later in the same body returns the closure-captured
pre-update value, not the just-assigned one. The compiler warns at
the read site so the bug is caught at compile time, not at runtime.
"""

cl {
    def:pub stale_demo() -> JsxElement {
        has logged_in: bool = False;

        can with entry {
            logged_in = True;       # write — schedules setLoggedIn(true)
            if logged_in {           # read — closure-captured pre-update value (False)
                logged_in = False;   # never reached on first run
            }
        }

        return <div>{logged_in}</div>;
    }
}
