obj MyObj {
    has x: int = 0;

    pass
}

class MyClass {
    def init(self: MyClass) {
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

edge MyEdge: any --> any {
    pass
}

with entry {
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
    } except Exception {
        pass;
    }
}

glob pass = 10;
with entry {
    my_list = [1, 2, pass];
    x = pass;
    print(pass);
}

def foo(pass: int) -> int {
    return pass + 1;
}

def pass {}
