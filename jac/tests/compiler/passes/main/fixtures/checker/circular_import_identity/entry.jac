"""Regression fixture: a circular import must not split a class's type identity."""

import from info { Info }

obj Tok {
    has val: int = 0;
}

obj Node {
    has info: Info;
}

def get_pair(n: Node) -> tuple[Tok, Tok] {
    return (n.info.first_tok, n.info.last_tok);
}
