"""Fixture: `del` on a plain local in a module with no graph archetypes."""

def del_plain -> int {
    x = 1;
    del x;
    return 7;
}
