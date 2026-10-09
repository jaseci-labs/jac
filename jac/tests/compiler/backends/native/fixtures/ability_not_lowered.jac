node Stop {
    has val: int;
}

walker Lister {
    can look with Stop exit {
        for neighbor in [-->] {
            print("neighbor", neighbor.val);
        }
    }
}

with entry {
    first = Stop(val=1);
    first ++> Stop(val=2);
    first spawn Lister();
}
