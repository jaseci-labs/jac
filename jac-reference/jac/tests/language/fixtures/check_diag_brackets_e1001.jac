"""Fixture for jac check diagnostic-snippet rendering test.

Triggers E1001 (assignment type mismatch) where the right-hand side is a
list comprehension wrapped in square brackets. The rendered source line in
the diagnostic must preserve the full comprehension — the console must not
interpret it as Rich markup.
"""

node Task {
    has title: str = "";
}

def maybe_task() -> Task | None {
    return None;
}

with entry {
    tasks: list[Task] = [];
    updated = maybe_task();
    tasks = [updated if t.title == "x" else t for t in tasks];
    print(tasks);
}
