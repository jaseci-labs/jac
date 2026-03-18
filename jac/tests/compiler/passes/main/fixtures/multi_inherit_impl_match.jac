"""Reproduces E2009 bug: class reassignment causes impl matching to fail."""

class MyClass {
    has value: int = 10;
    def get_value -> int;
}
with entry {
    (_, MyClass) = (1, MyClass);
}

impl MyClass.get_value -> int {
    return self.value;
}
