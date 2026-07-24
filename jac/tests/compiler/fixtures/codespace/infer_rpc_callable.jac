"""Client call to a def:pub endpoint that takes a function-typed parameter.

The endpoint bridges over RPC, but a function cannot serialize across the
wire — the compiler must say so (W6005) instead of letting the call fail
silently at runtime.
"""

glob _subs: list = [];

def:pub subscribe(cb: Callable[([str], None)]) -> int {
    _subs.append(cb);
    return len(_subs);
}

def _noop(msg: str) -> None {
    return;
}

def:pub app -> JsxElement {
    n = subscribe(_noop);
    return <div>{n}</div>;
}
