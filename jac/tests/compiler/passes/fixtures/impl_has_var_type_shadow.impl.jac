"""Impl file that reassigns a typed has variable.

A bare `tasks` in a method body is a local of that body: it never resolves
to the class's `has tasks`, which is reached through `self`.
"""

impl TaskManager.add_task(task: str) -> None {
    tasks = self.tasks + [task];
    self.tasks = tasks;
}

impl TaskManager.get_tasks -> list[any] {
    return self.tasks;
}
