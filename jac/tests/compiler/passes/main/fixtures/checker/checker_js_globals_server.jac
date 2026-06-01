"""Server-context fixture: JS globals must NOT leak into server code.

This is a plain `.jac` (server) module. `Date` is a browser/JS global with
no server runtime, so referencing it must stay a real error here -- the
client ambient stub is gated to client context and must not resolve.
"""

def now_diff() -> float {
    return Date.now();
}
