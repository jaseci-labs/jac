"""Fixture for E2080: Walker visits node type but no matching visit ability exists."""

node Start { }
node Middle { }
node End { }

walker Traverser {
    can on_start with Start entry {
        visit [-->];  # may visit Middle or End nodes
    }
    # Missing: can on_middle with Middle entry  # <-- Error E2080
    # Missing: can on_end with End entry         # <-- Error E2080
}
