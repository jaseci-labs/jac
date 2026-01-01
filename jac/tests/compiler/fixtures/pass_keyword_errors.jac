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

def foo() {
    pass;
}

with entry {

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

    pass = 10;
    my_list = [1, 2, pass];
}
