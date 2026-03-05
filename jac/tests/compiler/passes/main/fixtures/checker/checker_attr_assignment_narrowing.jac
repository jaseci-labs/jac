"""Test: Attribute assignment narrowing - self.attr = X should narrow type."""

obj Container {
    has value: int | None = None;
}

obj Doc {}
obj Text(Doc) {}

obj Holder {
    has _doc: Doc | None = None;

    @property
    def doc(self: Holder) -> Doc {
        if self._doc is None {
            self._doc = Text();  # Assignment should be allowed
        }
        return self._doc;  # Should be narrowed to Doc after assignment
    }
}

def test_attr_assignment_narrowing(c: Container) -> int {
    if c.value is None {
        c.value = 42;  # Assignment should be allowed (Doc | None target)
    }
    return c.value;  # Should return int (narrowed from int | None)
}

with entry {
    h = Holder();
    doc_result: Doc = h.doc;
    c = Container();
    int_result: int = test_attr_assignment_narrowing(c);
}
