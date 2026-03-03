"""Implementations for LSP core types."""

impl Position.__repr__ -> str {
    return f"{self.line}:{self.character}";
}

impl Position.__eq__(other: object) -> bool {
    if isinstance(other, Position) {
        return self.line == other.line and self.character == other.character;
    }
    return NotImplemented;
}

impl Position.__hash__ -> int {
    return hash((self.line, self.character));
}

impl Range.__repr__ -> str {
    return f"{self.start!r}-{self.end!r}";
}

impl Range.__eq__(other: object) -> bool {
    if isinstance(other, Range) {
        return self.start == other.start and self.end == other.end;
    }
    return NotImplemented;
}

impl Range.__hash__ -> int {
    return hash((self.start, self.end));
}

impl Location.__repr__ -> str {
    return f"{self.uri}:{self.range!r}";
}
