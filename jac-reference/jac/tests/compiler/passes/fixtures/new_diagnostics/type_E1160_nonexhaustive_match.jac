"""Fixture for E1160: Match is not exhaustive."""

enum Direction {
    NORTH,
    SOUTH,
    EAST,
    WEST
}

with entry {
    d = Direction.NORTH;

    # Non-exhaustive match -- missing WEST
    match d {
        case Direction.NORTH: print("north");  # <-- Error E1160 (on match stmt)
        case Direction.SOUTH: print("south");
        case Direction.EAST: print("east");
        # Missing WEST!
    }

    # Exhaustive match -- all covered
    match d {
        case Direction.NORTH: print("north");
        case Direction.SOUTH: print("south");
        case Direction.EAST: print("east");
        case Direction.WEST: print("west");  # <-- Ok
    }

    # Exhaustive via wildcard
    match d {
        case Direction.NORTH: print("north");
        case _: print("other");  # <-- Ok: wildcard covers rest
    }
}
