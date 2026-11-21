"""Whole-object borrow: any field write under it is still E1303."""

obj Player {
    has name: str = "",
        score: int = 0;
}

def use_player(x: Player) { }

with entry {
    p: own Player = Player();
    v: &Player = &p;
    p.score = 1;
    use_player(v);
}
