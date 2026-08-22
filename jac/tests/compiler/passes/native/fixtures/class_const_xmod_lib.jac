"""Fixture: the module that declares a class carrying class-level constants."""

obj Unit {
    with entry {
        SCALE: ClassVar[int] = 3;
        TAG: ClassVar[str] = "unit";
    }

    has n: int = 0;

    def scaled -> int {
        return self.n * self.SCALE;
    }
}


obj Double(Unit) {
    with entry {
        SCALE: ClassVar[int] = 6;
        TAG: ClassVar[str] = "double";
    }
}
