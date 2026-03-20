"""Test fixture for W2015: explicit self in obj/node/edge/walker methods."""

obj MyObj {
    has x: int = 0;

    def bad_method(self: MyObj, val: int) -> int {
        return self.x + val;
    }

    def good_method(val: int) -> int {
        return self.x + val;
    }

    static def static_method(val: int) -> int {
        return val;
    }
}

node MyNode {
    has label: str = "";

    def bad_method(self: MyNode) -> str {
        return self.label;
    }

    def good_method() -> str {
        return self.label;
    }
}

edge MyEdge {
    has weight: float = 1.0;

    def bad_method(self: MyEdge) -> float {
        return self.weight;
    }

    def good_method() -> float {
        return self.weight;
    }
}

walker MyWalker {
    has data: str = "";

    def bad_method(self: MyWalker) -> str {
        return self.data;
    }

    def good_method() -> str {
        return self.data;
    }
}

class PyClass {
    def __init__(self: PyClass) -> None {
        self.val = 42;
    }

    def method(self: PyClass) -> int {
        return self.val;
    }
}
