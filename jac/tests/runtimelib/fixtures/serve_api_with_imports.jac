"""Test Jac program that imports functions and walkers from another module."""

# Import functions and walkers from the importable module
import from serve_api_importable {
    multiply_numbers,
    format_message,
    ImportedItem,
    ImportedWalker,
    ImportedCounter
}

# Local node definition
node LocalTask {
    has title: str;
    has done: bool = False;
}

# Local walker definition
walker LocalCreateTask {
    has task_title: str;

    can create with `root entry {
        task = here ++> LocalTask(title=self.task_title);
        created = task[0] if task else None;
        if created {
            report created;
        }
    }
}

# Local function definition
def local_add(x: int, y: int) -> int {
    return x + y;
}

# Another local function
def local_greet(name: str = "Guest") -> str {
    return f"Welcome, {name}!";
}
