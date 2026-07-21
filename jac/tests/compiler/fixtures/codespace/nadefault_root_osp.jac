node Task {
    has title: str = "";
}

def add_task(title: str) -> int {
    root ++> Task(title=title);
    return 1;
}

with entry {
    print("added:", add_task("x"));
}
