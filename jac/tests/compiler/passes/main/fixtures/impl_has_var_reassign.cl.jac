"""Fixture: `has` var reassignment inside an impl body of a def-component.

Reproduces a bug where `tasks = tasks + [x]` in a separate `.impl.jac` file
loses the type of the parent `has` var and creates an untyped local shadow.
Inline method bodies in the same declaration file handle this correctly;
the impl-file path did not.

Expected: no type errors — `tasks` should resolve to the HasVar from the
enclosing def-component, matching the inline behavior.
"""

def:pub taskManager -> None {
    has tasks: list[dict] = [];
    async def addTask(task: dict) -> None;
    async def listTasks -> None;
}
