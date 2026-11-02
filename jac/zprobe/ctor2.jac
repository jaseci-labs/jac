obj A {
    has x: int = 1;
}

obj B(A) {
    has y: int = 2;

    def init(y: int) {
        self.y = y;
    }
}

obj C(B) {}

obj P {
    has v: int = 0;

    def postinit {
        self.v = self.v + 10;
    }
}

obj Q(P) {
    has w: int = 5;
}

with entry {
    b = B(5);
    assert b.y == 5;
    assert b.x == 1;
    assert C(7).y == 7;
    q = Q(1, 2);
    assert q.v == 11;
    assert q.w == 2;
}
