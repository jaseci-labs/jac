node Stop {
    has val: int;
}

edge Road : any --> any {}

walker Spy {
    can look with Stop entry {
        print(here.val);
    }
}

with entry {
    first = Stop(val=1);
    root spawn Spy();
    root +>:Road():+> first;
    sources = [Stop(val=2), Stop(val=3)];
    sources ++> [Stop(val=4), Stop(val=5)];
    print(first.val, len(sources));
}
