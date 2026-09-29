"""One of two modules that each define `obj CompressorState`."""

obj CompressorState {
    has chunks: list[int] = [],
        ratio: float = 0.5;

    def feed(size: int) -> None {
        self.chunks.append(size);
    }

    def describe -> str {
        return f"{len(self.chunks)}:{sum(self.chunks)}:{self.ratio}";
    }
}

def make_state(ratio: float) -> own CompressorState {
    state: own CompressorState = CompressorState(ratio=ratio);
    state.feed(3);
    return state;
}

def is_state(value: &object) -> bool {
    return isinstance(value, CompressorState);
}

def describe_all(states: &list[CompressorState]) -> str {
    return ",".join(state.describe() for state in states);
}
