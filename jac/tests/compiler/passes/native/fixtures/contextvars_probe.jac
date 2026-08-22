import from contextvars { ContextVar }

obj Req {
    has ident: str = "";
}

glob CUR: ContextVar[Req] = ContextVar[Req]("cur"),
     FALLBACK: ContextVar[Req] = ContextVar[Req](
         "fallback", `default=Req(ident="ctor-default")
     );

def unset_raises -> str {
    try {
        got = CUR.get();
        return "no-raise:" + got.ident;
    } except LookupError {
        return "LookupError";
    }
}

def run_probe {
    print(CUR.name);
    print(FALLBACK.name);
    print(unset_raises());
    print(CUR.get(Req(ident="call-default")).ident);
    print(FALLBACK.get().ident);
    print(FALLBACK.get(Req(ident="wins")).ident);
    CUR.set(Req(ident="first"));
    print(CUR.get().ident);
    print(CUR.get(Req(ident="ignored")).ident);
    CUR.set(Req(ident="second"));
    print(CUR.get().ident);
    print(unset_raises());
}

with entry {
    run_probe();
}
