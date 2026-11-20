node a {
    has val: int = 0;
}

node b {
    has val: int = 0;
}

node c {
    has val: int = 0;
}

with entry {
    x = [a(val=i) for i in range(0, 3)];
    y = [b(val=i) for i in range(0, 3)];
    z = [c(val=i) for i in range(0, 3)];

    x ++> y;
    y ++> z;

    print([x-->y-->z]);  # [c(val=0), c(val=1), c(val=2)]
    print([x-->y[:1]-->z[:1]]);  # [c(val=0)]
}
