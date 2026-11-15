node N {
    has val: int;
}

edge Road: any --> any {
    has km: int = 1;
}

glob calls: int = 0;

def bump -> int {
    calls += 1;
    return calls * 10;
}

glob none_left: list[N] = [];

with entry {
    hub = N(val=1);
    hub +>:Road:km=bump():+> [N(val=2), N(val=3), N(val=4)];
    print("assigned", calls, len([hub->:Road:km==10:->]));
    hub +>:Road:km=bump():+> none_left;
    print("assigned to none", calls);
    spoke = N(val=5);
    spoke +>:Road(km=bump()):+> [N(val=6), N(val=7)];
    print("built", calls, len([spoke->:Road:km==30:->]));
}
