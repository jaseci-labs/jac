"""Fixture: has variable type preserved across impl files.

Declares a list-typed has variable that is reassigned in an impl file.
Without the _fix_shadowed_parent_symbols fix, the has variable's type
annotation is lost and downstream passes treat it as untyped.
"""

obj TaskManager {
    has tasks: list = [],
        label: str = "default";

    def add_task(task: str) -> None;
    def get_tasks -> list;
}
