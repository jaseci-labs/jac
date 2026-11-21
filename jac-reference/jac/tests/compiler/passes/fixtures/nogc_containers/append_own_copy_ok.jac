"""Must stay clean: `own p` copies a borrowed str element into a fresh owned
value, which is the copy-in idiom the E1406 fix-it names."""
def run -> int {
    parts: own list[str] = ["a", "b"];
    out: own list[str] = [];
    for p in &parts {
        out.append(own p);
    }
    return len(out);
}

with entry {
    print(run());
}
