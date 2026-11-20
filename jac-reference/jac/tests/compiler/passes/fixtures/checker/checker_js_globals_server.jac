"""Server-context fixture: JS globals must NOT leak into server code.

The datetime import anchors this module server-side, so browser-global
seeding leaves `now_diff` in place. `Date` is a browser/JS global with no
server runtime, so referencing it must stay a real error here -- the
client ambient stub is gated to client context and must not resolve.
"""
import datetime;

def server_year -> int {
    return datetime.datetime.now().year;
}

def now_diff -> float {
    return Date.now();
}
