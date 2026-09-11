"""Copying an immutable scalar field creates independent mutable storage."""

obj Buffer {
    has n: int = 7;
}

def valid(input: imm Buffer) -> int {
    value = input.n;
    value += 1;
    return value;
}
