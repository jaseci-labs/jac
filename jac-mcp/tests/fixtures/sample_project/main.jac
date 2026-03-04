"""Sample project for testing project-aware features."""

node TaskNode {
    has title: str,
        done: bool = False;
}

edge DependsOn {
    has priority: int = 0;
}

walker TaskRunner {
    has completed: list[str] = [];

    can run_task with TaskNode entry;
}
