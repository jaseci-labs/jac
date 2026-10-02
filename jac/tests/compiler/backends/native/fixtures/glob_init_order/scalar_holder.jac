"""Globals computed from `scalar_table`'s computed globals."""

def slot_bytes -> int {
    return 8;
}

import from scalar_table { WIDTH, COUNT }

glob SIZE: int = WIDTH * COUNT + 4,
     SLOTS: int = SIZE // slot_bytes();
