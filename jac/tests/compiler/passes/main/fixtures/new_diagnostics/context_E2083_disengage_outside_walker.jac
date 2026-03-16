"""Fixture for E2083: disengage used outside of walker ability."""

obj NotAWalker {
    def method(self: NotAWalker) -> None {
        disengage;  # <-- Error E2083
    }
}

walker MyWalker {
    can visit_node with `root entry {
        disengage;  # <-- Ok
    }
}
