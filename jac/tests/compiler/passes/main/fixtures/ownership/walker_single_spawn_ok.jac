"""One spawn per own walker: results move out cleanly, no diagnostics."""

node Spot {
    has v: int = 0;
}

walker Visitor {
    has total: int = 0;

    can tally with Spot entry {
        self.total += here.v;
    }
}

with entry {
    s = Spot(v=5);
    w: own Visitor = Visitor();
    res = w spawn s;
    print(res.total);
}
