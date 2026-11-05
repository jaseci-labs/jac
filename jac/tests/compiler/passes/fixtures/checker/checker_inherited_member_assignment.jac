class Base {
    has _elements: list[int] | None = None;
}

class Ident(Base) {
    def set_body(self: Ident, elems: list[int]) {
        members: list[int] = self._elements;
        self._elements = list(elems);
    }
}

class Annotated {
    def init(self: Annotated) {
        self.count: int | None = None;
    }
}

class Counter(Annotated) {
    def bump(self: Counter) {
        total: int = self.count;
        self.count = 1;
    }
}

class Fresh {
    def set_label(self: Fresh) {
        self.label = "x";
        value: str = self.label;
    }
}
