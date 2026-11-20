"""Seal requires an owned handle: through a borrowed &Region it stays E1307."""

node City {
    has name: str = "";
}

def grow(r: &Region, anchor: City) {
    in r {
        a = City(name="a");
        anchor ++> a;
    }
}
