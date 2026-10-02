"""One of two modules that each define `obj CompressorState`."""

obj CompressorState {
    has level: int,
        flushed: bool = False,
        label: str = "bz";

    def describe -> str {
        return f"{self.label}:{self.level}:{self.flushed}";
    }
}

def make_state(level: int) -> own CompressorState {
    return CompressorState(level=level);
}

def is_state(value: &object) -> bool {
    return isinstance(value, CompressorState);
}

def describe_all(states: &list[CompressorState]) -> str {
    return ",".join(state.describe() for state in states);
}
