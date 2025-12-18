# Global and Nonlocal Statements
glob x = "global x";
glob
    a = 1,
    b = 2;

def test_global {
    # Global with single name
    global x;
    x = "modified global x";
    print(x);
}

def test_multiple_globals {
    # Global with multiple names
    global a,b;
    a = 10;
    b = 20;
    print(f"{a} {b}");
}

def outer {
    y = "outer y";

    def inner {
        # Nonlocal with single name
        nonlocal y ;
        y = "modified by inner";
        print(y);
    }

    print(y);
    inner();
    print(y);
}

def outer_multi {
    p = 1;
    q = 2;
    r = 3;

    def inner_multi {
        # Nonlocal with multiple names
        nonlocal p , q , r ;
        p = 10;
        q = 20;
        r = 30;
    }

    print(f"{p} {q} {r}");
    inner_multi();
    print(f"{p} {q} {r}");
}

with entry {
    print(x);
    test_global();
    print(x);

    print(f"{a} {b}");
    test_multiple_globals();
    print(f"{a} {b}");

    outer();
    outer_multi();
}
