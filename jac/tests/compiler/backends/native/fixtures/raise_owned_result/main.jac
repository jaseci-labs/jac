"""Raising an exception object returned by a call keeps it alive for the handler."""
obj Val {
    has tag: int = 0;
}

obj StrVal(Val) {
    has text: str = "";
}

obj ExcVal(Val) {
    has kind: str,
        args: list[Val] = [];
}

obj Raised(Exception) {
    has exc: ExcVal,
        user: bool = False;
}

def make_raise(msg: str) -> Raised {
    return Raised(exc=ExcVal(kind="ValueError", args=[StrVal(text=msg)]), user=True);
}

def text_of(v: Val) -> str {
    if isinstance(v, StrVal) {
        return v.text;
    }
    if isinstance(v, ExcVal) and v.args {
        return text_of(v.args[0]);
    }
    return "?";
}

def fail_with(msg: str) -> int {
    raise make_raise(msg);
}

def chk_raise_owned_result -> int {
    try {
        fail_with("boom");
    } except Raised as e {
        return len(text_of(e.exc)) * 10 + (1 if e.user else 0);
    }
    return 0;
}

with entry {
    print(chk_raise_owned_result());
}
