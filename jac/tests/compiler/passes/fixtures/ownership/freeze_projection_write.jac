"""A container projected from an immutable input remains readonly."""

obj Buffer {
    has values: list[int] = [];
}

def invalid(input: imm Buffer) {
    values = input.values;
    alias = values;
    alias.append(9);
}
