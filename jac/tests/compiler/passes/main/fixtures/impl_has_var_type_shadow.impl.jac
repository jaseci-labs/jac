"""Impl file that reassigns a typed has variable.

The assignment `tasks = tasks + [task]` should resolve `tasks` to the
HasVar symbol from the parent scope, not create a new untyped local var.
"""

impl TaskManager.add_task(task: str) -> None {
    tasks = tasks + [task];
}

impl TaskManager.get_tasks -> list {
    return tasks;
}
