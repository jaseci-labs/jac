"""Python-backed ContextVar instances retain their scalar values."""

import from contextvars { ContextVar }

glob N: ContextVar[int] = ContextVar[int]("n", `default=7);

def scalar_value -> int {
    return N.get();
}

def run_probe {
    print(scalar_value());
}

with entry {
    run_probe();
}
