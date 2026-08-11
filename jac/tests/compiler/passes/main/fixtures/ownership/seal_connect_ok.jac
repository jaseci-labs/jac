"""Connect-as-seal: attaching region topology to a managed anchor
consumes the owned handle and promotes the subgraph -- no diagnostics."""

node City {
    has name: str = "";
}

def run {
    anchor = City();
    r: own Region = Region();
    in r {
        a = City(name="a");
        b = City(name="b");
        a ++> b;
        anchor ++> a;
    }
}
