"""views are derivation-bounded in enforced modules: storing one into
a container is E1315; returning one with two borrow candidates ties the
result to both (no diagnostic). A slice of an owned `str` is a view of
that owner, not a move of it: `piece` below borrows `w`, so `fw = imm w`
sees an intact owner and `outlive` checks clean (an earlier checker typed
the slice `LiteralString`, which the ownership pass could not recognize as
a str view, so the slice was counted as a move and `imm w` reported
E1301)."""

def stash(s: &str, out: &mut list[str]) {
    piece = s[0:2];
    out.append(piece);
}

def pick(a: &str, b: &str) -> str {
    return a[0:1];
}

def outlive -> int {
    w: own str = "abc" + "def";
    piece = w[1:3];
    fw = imm w;
    return len(piece);
}
