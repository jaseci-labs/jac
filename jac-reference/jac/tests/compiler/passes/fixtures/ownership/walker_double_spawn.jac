"""An own walker is affine computation: the second spawn is use-after-move."""

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
    res2 = w spawn s;
    print(res2.total);
}
