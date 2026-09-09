"""Must fail (E1406): a loop borrow of an owned list's element cannot enter
another owned list as it is; the diagnostic names the borrow, its owner, the
container, and the two idioms that fit (`own p`, or iterating by value)."""
def run -> int {
    parts: own list[str] = ["a", "b"];
    out: own list[str] = [];
    for p in &parts {
        out.append(p);
    }
    return len(out);
}

with entry {
    print(run());
}
