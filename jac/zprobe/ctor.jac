obj PA { has a: int = 0; }
obj PB { has b: int = 0; }
obj PC(PA, PB) {}

obj HA {
    has x: int = 0;
    def init(y: int) { self.x = y * 2; }
}
obj HB(HA) {}

def show(v: object) -> None { v; }

with entry {
    c = PC(1, 2);
    assert c.b == 1;
    assert c.a == 2;
    assert HB(3).x == 6;
}
