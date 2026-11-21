"""The non-seal directions stay rejected: a region edge wired out to a
managed node (or undirected wiring) is still E1307."""

node City {
    has name: str = "";
}

def run {
    anchor = City();
    other = City();
    r: own Region = Region();
    in r {
        a = City(name="a");
        b = City(name="b");
        a ++> anchor;
        b <++> other;
    }
}
