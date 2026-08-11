"""Seal consumes the handle: reopening it afterwards is E1301."""

node City {
    has name: str = "";
}

def run {
    anchor = City();
    r: own Region = Region();
    in r {
        a = City(name="a");
        anchor ++> a;
    }
    in r {
        b = City(name="b");
        print(b.name);
    }
}
