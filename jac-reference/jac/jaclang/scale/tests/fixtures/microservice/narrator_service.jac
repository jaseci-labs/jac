"""Streaming provider: a `def:pub` that yields is served as SSE, one frame per yield."""

import from typing { Generator }

def:pub narrate(n: int) -> Generator[str, None, None] {
    for i in range(n) {
        yield f"chunk {i}";
    }
}
