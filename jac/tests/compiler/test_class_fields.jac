import from jaclang.runtime.object_interop { fields }

obj ErrorCodes {
    static has INVALID_ARGS: str = "INVALID_ARGS",
        FORBIDDEN: str = "FORBIDDEN";
}

obj Calculator {
    static has PI: float = 3.14;

    static def circle_area(r: float) -> float {
        return Calculator.PI * r * r;
    }
}

obj EscapedFields {
    has `init: bool,
        `postinit: int;

    def init {
        self.`init = True;
        self.`postinit = 7;
    }

    def read -> bool {
        return self.`init;
    }
}

test "static fields remain class values" {
    assert ErrorCodes.INVALID_ARGS == "INVALID_ARGS";
    assert ErrorCodes.FORBIDDEN == "FORBIDDEN";
    assert not fields(ErrorCodes);
    assert Calculator.circle_area(2.0) == 12.56;
}

test "escaped fields do not replace constructor methods" {
    record = EscapedFields();
    assert getattr(record, "init") is True;
    assert getattr(record, "postinit") == 7;
    assert callable(record.__init__);
    assert record.read();
}
