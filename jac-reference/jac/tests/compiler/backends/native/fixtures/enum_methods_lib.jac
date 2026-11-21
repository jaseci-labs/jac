enum ForeignPriority: int {
    LOW = 5,
    HIGH = 13,
    with entry {
        def scaled(self: ForeignPriority, scale: int = 3) -> int {
            return self.value * scale;
        }
    }
}
