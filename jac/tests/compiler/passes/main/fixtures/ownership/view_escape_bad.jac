"""views are derivation-bounded in enforced modules: storing one into
a container is E1315; returning one with two borrow candidates is
E1315; a view outliving its consumed owner is E1301 via the borrow
machinery views ride on."""

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
