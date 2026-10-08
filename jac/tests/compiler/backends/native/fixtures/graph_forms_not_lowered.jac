node Stop {
    has val: int;
}

with entry {
    first = Stop(val=1);
    root ++> first;
    hub = Stop(val=2);
    hub ++> [Stop(val=3), Stop(val=4)];
    print(first.val, hub.val);
}
