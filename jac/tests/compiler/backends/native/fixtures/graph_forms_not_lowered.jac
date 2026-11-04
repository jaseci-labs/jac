node Stop {
    has val: int;
}

edge Road: any --> any {}

walker Spy {
    can look with Stop entry {
        print(here.val);
    }
}

def spawn_at_root {
    root spawn Spy();
}

def road_from_root(first: Stop) {
    root +>:Road():+> first;
}

def lists_both_sides -> int {
    sources = [Stop(val=2), Stop(val=3)];
    sources ++> [Stop(val=4), Stop(val=5)];
    return len(sources);
}

with entry {
    first = Stop(val=1);
    spawn_at_root();
    road_from_root(first);
    print(first.val, lists_both_sides());
}
