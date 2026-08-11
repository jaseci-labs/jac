"""The cast target is a type production: an operator after it is a syntax
error rather than being silently absorbed into the cast type (#7885)."""

with entry {
    x: int = 3;
    print(x as int + 1);
}
