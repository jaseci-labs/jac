"""Must-fail under --memory nogc: any-typed parameter could be heap (E1404)."""

def show(v: any) {
    print(v);
}

with entry {
    show(42);
}
