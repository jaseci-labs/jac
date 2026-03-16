"""Fixture for E2042: Cannot inherit from final archetype."""

import from typing { final }

@final
obj Singleton {
    has instance: int = 0;
}

obj Extended(Singleton) {  # <-- Error E2042: Singleton is final
    has extra: str = "nope";
}
