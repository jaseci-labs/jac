class Contract {
    def value(self: Contract, x: int) -> int abst;
    static def label -> str abst;
}

class Concrete(Contract) {
    def value(self: Concrete, x: int) -> int {
        return x + 1;
    }

    static def label -> str {
        return "ready";
    }
}

test "abstract instance and static methods require concrete overrides" {
    assert getattr(Contract, "__abstractmethods__") == {"value", "label"};
    with testraises(TypeError) {
        Contract();
    }
    assert Concrete().value(7) == 8;
    assert Concrete.label() == "ready";
}
