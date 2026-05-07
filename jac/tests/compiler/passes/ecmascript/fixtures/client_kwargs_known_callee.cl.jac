"""Plain client-side kwargs lowering — regression fixture for issue #5852.

A client-side function (not an sv-imported RPC stub) called with kwargs
or mixed positional/kwarg syntax must lower to a positional JS call
matching the declared parameter order.  Previously the compiler packed
all kwargs into a single object literal and dropped any preceding
positional args, e.g. ``add(b=10, a=5)`` → ``add({b:10, a:5})`` (passed
the object as ``a``, leaving ``b`` undefined) and ``add(1, b=2)`` →
``add({b:2})`` (silently dropped the positional ``1``).
"""

def add(a: int, b: int) -> int {
    return a + b;
}

def:pub app -> JsxElement {
    has total: int = 0;

    # Pure kwargs, source order != declaration order
    def call_kwargs_only -> None {
        total = add(b=10, a=5);
    }

    # Mixed positional + kwarg
    def call_mixed -> None {
        total = add(1, b=2);
    }

    # All positional — must keep working unchanged
    def call_positional -> None {
        total = add(3, 4);
    }

    return <div><p>{total}</p></div>;
}
