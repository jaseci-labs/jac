"""`new(cls, ...)` must return an instance of `cls`, not bare `object`.

The `new` builtin is generic over its class argument (`type[T] -> T`), so a
method that exists on the constructed type resolves, while a missing one is
still flagged. If `new` collapsed to `object`, `render()` below would wrongly
error too.
"""

obj Widget {
    has size: int = 0;
    def render() -> str { return "ok"; }
}

def build() -> str {
    w = new(Widget, 5);
    return w.render();
}

def broken() -> str {
    w = new(Widget);
    return w.nope();
}
