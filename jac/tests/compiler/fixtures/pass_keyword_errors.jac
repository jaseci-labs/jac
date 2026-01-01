obj MyObj {
    has x: int = 0;
    pass
}

class MyClass {
    def __init__(self: MyClass) {
        pass;
    }
    pass
}

node MyNode {
    has y: float = 0.0;
    pass
}

walker MyWalker {
    pass
}

edge MyEdge {
    pass
}

def foo(pass: int) -> int {
    return pass + 1;
}

with entry {

    my_list = [1, 2, pass];
    pass = 10;
    x = pass;
    print(pass);
    pass;

    if True {
        print("Hello");
        pass;
    }

    for i in [1, 2, 3] {
        print(i);
        pass;
    }

    try {
        x = 1 / 0;
    } except Exception{
        pass;
    }

}
