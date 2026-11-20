"""Same field: writing the field a shared borrow points at is still E1303."""

obj Player {
    has name: str = "",
        score: int = 0;
}

def use_name(x: str) { }

with entry {
    p: own Player = Player();
    v: &str = &p.name;
    p.name = "x";
    use_name(v);
}
