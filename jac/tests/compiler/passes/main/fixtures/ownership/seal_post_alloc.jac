"""The seal closes the region for graph operations: instantiating or
connecting after it inside the open is E1307."""

node City {
    has name: str = "";
}

def run {
    anchor = City();
    r: own Region = Region();
    in r {
        a = City(name="a");
        anchor ++> a;
        c = City(name="late");
        a ++> c;
    }
}
