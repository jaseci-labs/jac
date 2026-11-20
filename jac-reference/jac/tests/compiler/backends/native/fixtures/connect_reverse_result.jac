"""A connect written toward its source yields the destination side."""

node N {
    has val: int;
}

walker W {
    has seen: list[int] = [];

    can step with N entry {
        self.seen.append(here.val);
        visit [-->];
    }
}

with entry {
    src = N(val=1);
    sinks = [N(val=2), N(val=3)];
    back = (sinks <++ src);
    print("reverse list dest", len(back));
    hub = N(val=10);
    feeders = [N(val=11), N(val=12)];
    got = (hub <++ feeders);
    print("reverse node dest", got.val);
    w = src spawn W();
    print(w.seen);
}
