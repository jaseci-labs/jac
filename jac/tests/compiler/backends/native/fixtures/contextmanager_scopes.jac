"""The compiler's own scope shapes: ContextVar-backed @contextmanager scopes.

`cache_scope` / `wiring_scope` / `compilation_scope` mirror
`compilation_context.jac` and `wiring.jac`: a `ContextVar[X | None]` with an
explicit `default=None`, a scope that yields and returns early when one is
already open, a scope composed of two others inside a generator, and a
`ContextVar('x', default=False)` reentrancy guard with an inferred type.
"""

import from contextlib { contextmanager }
import from contextvars { ContextVar }

obj Options {
    has level: int = 0;
}

obj Spec {
    has name: str = "";
}

glob _active: ContextVar[Options | None] = ContextVar('active', `default=None),
     _resolution: ContextVar[dict[str, Spec | None] | None] = ContextVar(
         'resolution', `default=None
     ),
     _loading = ContextVar('loading', `default=False);

@contextmanager
def cache_scope(options: Options | None = None) -> Iterator[None] {
    token = _active.set(options);
    try {
        yield ;
    } finally {
        _active.reset(token);
    }
}

@contextmanager
def wiring_scope -> Iterator[None] {
    if _resolution.get() is not None {
        yield ;
        return;
    }
    token = _resolution.set({});
    try {
        yield ;
    } finally {
        _resolution.reset(token);
    }
}

@contextmanager
def compilation_scope(options: Options | None = None) -> Iterator[None] {
    with cache_scope(options), wiring_scope() {
        yield ;
    }
}

def level -> int {
    cur = _active.get();
    return cur.level if cur is not None else -1;
}

def resolved -> int {
    res = _resolution.get();
    return len(res) if res is not None else -1;
}

def note(name: str) {
    res = _resolution.get();
    if res is not None {
        res[name] = Spec(name=name);
    }
}

def loading_guard(n: int) -> int {
    if _loading.get() {
        return 0;
    }
    tok = _loading.set(True);
    try {
        return n + loading_guard(n - 1);
    } finally {
        _loading.reset(tok);
    }
}

with entry {
    print("before", level(), resolved());
    with compilation_scope(Options(level=2)) {
        print("in", level(), resolved());
        note("a");
        with compilation_scope(Options(level=5)) {
            note("b");
            print("inner", level(), resolved());
        }
        print("back", level(), resolved());
    }
    print("after", level(), resolved());
    try {
        with compilation_scope(Options(level=9)) {
            print("raising", level());
            raise ValueError("x");
        }
    } except ValueError {
        print("caught", level(), resolved());
    }
    print("guard", loading_guard(4), _loading.get());
}
