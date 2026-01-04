"""Implementation file for nested class signature test.

Tests that auto-lint properly fixes nested class impl signatures to match
their declarations (not the parent class declarations).
"""

impl OuterClass.init(self: OuterClass, shared: int, private: int) -> None {
    self.value = shared + private;
}

# WRONG signature: has (a: int, b: int) but decl has (name: str)
# Auto-lint should fix this to match InnerClass.init, NOT OuterClass.init
impl OuterClass.InnerClass.init(self: OuterClass.InnerClass, a: int, b: int) -> None {
    self.name = name;
}

# WRONG signature: has (foo: str) but decl has (x: int, y: int, *, z: int = 0)
# Auto-lint should fix this to match AnotherInner.init, NOT OuterClass.init
impl OuterClass.AnotherInner.init(self: OuterClass.AnotherInner, foo: str) -> None {
    self.x = x;
    self.y = y;
    self.z = z;
}

# WRONG signature: has (wrong: int) but decl has (data: str)
impl OuterClass.process(wrong: int) -> str {
    return data.upper();
}
