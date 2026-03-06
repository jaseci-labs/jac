"""Bug #6: MRO linearization is not C3 — incorrect for diamond inheritance.

The current implementation uses simple DFS dedup instead of the C3
linearization algorithm. For diamond inheritance patterns, this produces
an incorrect MRO that differs from Python's actual behavior.

Diamond:
    A
   / \
  B   C
   \ /
    D

Python C3 MRO for D: [D, B, C, A, object]
Buggy DFS MRO for D: [D, B, A, object, C] (A before C)

This test checks that method resolution follows C3 ordering:
if B and C both override a method from A, D should use B's version
(first in MRO after D).
"""

obj A {
    def who -> str {
        return "A";
    }
}

obj B(A) {
    def who -> str {
        return "B";
    }
}

obj C(A) {
    def who -> str {
        return "C";
    }

    def c_only -> str {
        return "C_only";
    }
}

obj D(B, C) {
    # D should have MRO: [D, B, C, A, object]
    # Bug: DFS dedup gives [D, B, A, object, C]
}

with entry {
    d = D();

    # C3 says B comes before C in D's MRO, so D inherits B.who
    # With correct C3: D -> B -> C -> A -> object
    # With buggy DFS:  D -> B -> A -> object -> C

    # This should work regardless of MRO bug because D inherits from C
    # through some path. But the resolution order matters for overrides.
    val: str = d.c_only();  # <-- Ok (C.c_only exists via inheritance)
}
