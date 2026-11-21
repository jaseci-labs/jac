"""Heap-free globals read across an import cycle while modules initialize,
for every memory profile (a nogc build keeps no heap value in a global)."""

import from scalar_holder { SIZE, SLOTS }
import from scalar_table { describe }

with entry {
    print(SIZE, SLOTS, describe());
}
