"""A nested definition must not consume its enclosing event's open region."""
node Spot {
    has value: int = 0;
}

walker Counter {
    has total: int = 0;

    can count with Spot entry {
        def twice(value: int) -> int {
            return value * 2;
        }
        self.total += twice(here.value);
        if here.value < 3 {
            here ++> Spot(value=here.value + 1);
            visit [-->];
        }
    }
}

def scenario -> int {
    region: own Region = Region();
    result = 0;
    in region {
        seed = Spot(value=1);
        counter = seed spawn Counter();
        result = counter.total;
    }
    return result;
}
