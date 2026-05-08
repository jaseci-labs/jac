"""Walker `has reports: list[T]` should drive type-checking of:
  1. The shape of the declaration itself (must be a list type).
  2. The element type of every `report X` statement in the walker body.
"""

obj Task {
    has title: str = "";
}

walker GoodWalker {
    has reports: list[Task] = [];

    can with entry {
        report Task(title="hi");   # OK: Task is the declared element type
    }
}

walker MismatchedReport {
    has reports: list[Task] = [];

    can with entry {
        report 42;                 # ERROR: int is not assignable to Task
    }
}

walker BadShape {
    has reports: int = 0;          # ERROR: reports must be a list type
}
