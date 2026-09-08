"""Constructed edge expressions preserve their graph type through grouping."""

node N {}

edge Named: N --> N {
    has name: str;
}

def probe -> int {
    r: own Region = Region();
    in r {
        a = N();
        b = N();
        a +>:(Named(name="value")):+> b;
        found = [edge a->:Named:name=="value":->];
        return len(found);
    }
}
