node c {
    has cc: int = 9;
}

edge aaa {
    has vvv: int = 45;
}

node a {
    has aa: int = 1;
}

node b {
    has bb: int = 4;
}

with entry {
    x = [a(aa=x) for x in range(0, 3)];
    y = [b(bb=x) for x in range(0, 3)];
    z = [c(cc=x) for x in range(0, 3)];
    x <++> y;  # just adding one trigger of undirected connect
    y ++> z;
    apple: int;
    # print(x ->:aaa:-> );
    print([x-->y-->z]);
    print([x-->]);
    print(x del --> y);
    print([x-->]);
    print([i.__class__.__name__ for i in (x ++> y)]);
    print([i.__class__.__name__ for i in ([edge x[0]-->y])]);
}
