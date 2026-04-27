"""Fixture for W3040: Filter comparison tautology on shadowed names."""

node Task {
    has to_user: str;
}

walker FindTasks {
    can find_tasks with root entry {
        to_user = "alice";
        # W3040: both sides resolve to the same node field
        tasks_bad = [root()-->][?:Task, to_user==to_user];
    }
}
