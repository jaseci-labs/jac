"""Must stay clean: a str method called on a borrowed element yields a fresh
str that moves into an owned list. The receiver narrows to a literal type, so
the call resolves to the `LiteralString` overload, which the fence must treat
as str."""
def run -> int {
    line: own str = "a,b,c,d";
    parts: own list[str] = line.split(",");
    out: own list[str] = [];
    for p in &parts {
        out.append(p.upper());
    }
    return len(out);
}

with entry {
    print(run());
}
