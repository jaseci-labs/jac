"""Impl file: reassignment must resolve `tasks` to the parent HasVar.

Also checks that annotated locals keep their own binding (Python shadowing),
so the fix does not over-apply.
"""

impl taskManager.addTask(task: dict) -> None {
    tasks = tasks + [task];
}

impl taskManager.listTasks -> None {
    x: list[dict] = tasks;
    # Annotated local with a distinct name is an ordinary local binding, not
    # a has-var reassignment. It must NOT collapse into the HasVar.
    local_count: int = 0;
}
