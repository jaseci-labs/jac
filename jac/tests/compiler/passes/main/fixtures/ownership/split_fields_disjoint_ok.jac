"""Disjoint fields: a shared borrow of one field must not block writes to another."""

obj Player {
    has name: str = "",
        score: int = 0;
}

def use_name(x: str) { }

with entry {
    p: own Player = Player();
    v: &str = &p.name;
    p.score = 1;
    use_name(v);
}
