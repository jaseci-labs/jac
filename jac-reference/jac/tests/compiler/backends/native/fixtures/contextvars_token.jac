import from contextvars { ContextVar }

obj Req {
    has ident: str = "";
}

glob CUR: ContextVar[Req] = ContextVar[Req]("cur"),
     OTHER: ContextVar[Req] = ContextVar[Req]("other");

def current -> str {
    try {
        return CUR.get().ident;
    } except LookupError {
        return "unset";
    }
}

def run_probe {
    first = CUR.set(Req(ident="first"));
    print(current(), first.var is CUR);
    second = CUR.set(Req(ident="second"));
    print(current(), second.old_value.ident if second.old_value else "none");
    CUR.reset(second);
    print(current());
    CUR.reset(first);
    print(current());
    try {
        CUR.reset(first);
    } except RuntimeError {
        print("reused token: RuntimeError");
    }
    third = OTHER.set(Req(ident="x"));
    try {
        CUR.reset(third);
    } except ValueError {
        print("foreign token: ValueError");
    }
    print(OTHER.get().ident);
    with CUR.set(Req(ident="scoped")) {
        print(current());
    }
    print(current());
}

with entry {
    run_probe();
}
