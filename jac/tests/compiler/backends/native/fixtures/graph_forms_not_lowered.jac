node Stop {
    has val: int;
}

def through_root -> Stop {
    first = Stop(val=1);
    root ++> first;
    return first;
}

def fan_out -> Stop {
    hub = Stop(val=2);
    hub ++> [Stop(val=3), Stop(val=4)];
    return hub;
}

with entry {
    print(through_root().val, fan_out().val);
}
