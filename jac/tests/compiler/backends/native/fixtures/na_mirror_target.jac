"""Regression fixture: a module pinned native whose members must stay usable.

The server-side client (na_mirror_client.jac) imports and constructs these
from the server codespace. Before the mirror splice the client's import was
dropped outright (`Import.native_only_drop`), so every imported name was
unbound and constructing MirrorPoint raised NameError at execution.
"""

obj MirrorPoint {
    has x: int = 0,
        y: int = 0;

    def sum2 -> int {
        return self.x + self.y;
    }
}

def mirror_double(v: int) -> int {
    return v * 2;
}
