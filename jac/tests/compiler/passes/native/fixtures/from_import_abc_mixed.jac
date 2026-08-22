"""One non-erasable name in a `from` list refuses the whole import.

`ABC` is compile-time and erases; `abstractmethod` is not, because the
keyword forms (`abst`, `class def`, `static def`) are what cross into native
and the decorator spellings demote. The vocabulary is per name, not per
module, so listing both must still refuse.
"""

import from abc { ABC, abstractmethod }


obj Shape(ABC) {
    has n: int = 3;
}


def run -> int {
    return Shape(n=4).n;
}
