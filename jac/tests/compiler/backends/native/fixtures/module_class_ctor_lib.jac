"""Class-form archetypes another module constructs through a module alias."""
class Scope {
    has names: set[str];

    def init(self: Scope) {
        self.names = {''};
    }

    def count(self: Scope) -> int {
        return len(self.names);
    }
}

class Kind {
    def width(self: Kind) -> int {
        return 0;
    }
}

class IntKind(Kind) {
    has bits: int = 0;

    def init(self: IntKind, bits: int) {
        self.bits = bits;
    }

    def width(self: IntKind) -> int {
        return self.bits;
    }
}
