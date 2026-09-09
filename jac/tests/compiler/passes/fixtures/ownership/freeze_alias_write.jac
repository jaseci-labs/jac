"""A local alias chain cannot restore write access to a frozen reference."""

obj Buffer {
    has n: int = 0;
}

def invalid {
    owner: own Buffer = Buffer(n=7);
    frozen = imm owner;
    alias = frozen;
    nested = alias;
    nested.n = 9;
}
