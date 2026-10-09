node Stop {
    has val: int;
}

with entry {
    first = Stop(val=1);
    root ++> first;
    sources = [Stop(val=2), Stop(val=3)];
    sources ++> [Stop(val=4), Stop(val=5)];
    print(first.val, len(sources));
}
