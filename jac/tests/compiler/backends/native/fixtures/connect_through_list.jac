node N {
    has val: int;
}

edge Road: any --> any {
    has km: int = 1;
}

walker W {
    has seen: list[int] = [];

    can step with N entry {
        self.seen.append(here.val);
        visit [-->];
    }
}

with entry {
    hub = N(val=1);
    hub ++> [N(val=2), N(val=3)];
    w1 = hub spawn W();
    print("fan out", w1.seen);

    sink = N(val=9);
    feeders = [N(val=5), N(val=6)];
    feeders ++> sink;
    w2 = feeders[0] spawn W();
    w3 = feeders[1] spawn W();
    print("fan in", w2.seen, w3.seen);

    start = N(val=10);
    start +>:Road(km=7):+> [N(val=11), N(val=12)];
    w4 = start spawn W();
    print("typed", w4.seen);

    tail = N(val=20);
    tail ++> [N(val=21)];
}

glob empty: list[N] = [];
with entry {
    tail ++> empty;
    w5 = tail spawn W();
    print("single and empty", w5.seen);
}
