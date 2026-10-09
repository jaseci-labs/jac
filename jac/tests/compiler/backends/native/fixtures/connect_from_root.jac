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
    a = N(val=1);
    b = N(val=2);
    c = N(val=3);
    root ++> a ++> b ++> c;
    w1 = a spawn W();
    print("chain", w1.seen);
    d = N(val=4);
    root +>:Road(km=2):+> d;
    d ++> N(val=5);
    w2 = d spawn W();
    print("typed", w2.seen);
}
