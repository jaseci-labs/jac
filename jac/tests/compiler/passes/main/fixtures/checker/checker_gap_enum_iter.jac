"""Gap #45: Enum iteration raises false positive error.

Iterating over an enum class is valid Python/Jac (EnumMeta provides
__iter__). The type checker raises a false error because the enum
class type doesn't have __iter__ in its symbol table/MRO.

Expected: 0 errors. All enum iteration patterns below are valid.
"""

enum Color { RED = 1, GREEN = 2, BLUE = 3 }

enum Direction {
    NORTH = "N",
    SOUTH = "S",
    EAST = "E",
    WEST = "W"
}

enum Priority { LOW, MEDIUM, HIGH }

with entry {
    # Case 1: Simple for loop over enum
    for c in Color {
        print(c);
    }

    # Case 2: Iterate over string-valued enum
    for d in Direction {
        print(d);
    }

    # Case 3: Iterate over auto-valued enum
    for p in Priority {
        print(p);
    }

    # Case 4: List comprehension over enum
    color_names: list = [c.name for c in Color];

    # Case 5: Enum in conditional iteration
    for d in Direction {
        if d == Direction.NORTH {
            print("Going north!");
        }
    }

    # Case 6: len() on enum (EnumMeta provides __len__)
    count = len(Color);

    # Case 7: Membership test (in operator on enum class)
    exists = Color.RED in Color;
}
