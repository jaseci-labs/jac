"""Test impl_def inside archetype body."""

obj Base {
    def greet() -> str;
}

obj Container {
    impl Base.greet() -> str {
        return "Hello from Container";
    }
}
