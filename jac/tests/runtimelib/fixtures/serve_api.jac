"""Example Jac program for REST API server."""

import from "@jac/runtime" { renderJsxTree, }

# Define some nodes
node Task {
    has title: str,
        completed: bool = False,
        priority: int = 0;
}

node User {
    has name: str,
        email: str;
}

# Define a walker to create tasks
walker:protect CreateTask {
    has title: str,
        priority: int = 1;

    can create with Root entry {
        task = here ++> Task(title=self.title, priority=self.priority);
        if task {
            print("Created task: " + task.title);
            report task;
        }
        root spawn CompleteTask(title=self.title);
    }
}

# Define a walker to list all tasks
walker:protect ListTasks {
    has tasks: list[any] = [];

    can collect with Root entry {
        visit [-->];
        completed_tasks_walker = root spawn ListCompletedTasks();
        report completed_tasks_walker.completed_tasks;
    }

    can gather with Task entry {
        print("Found task: " + here.title);
    }
}

# Define a walker to List completed Tasks
walker:protect ListCompletedTasks {
    has completed_tasks: list[any] = [];

    can collect with Root entry {
        visit [-->];
    }

    can gather with Task entry {
        if here.completed {
            self.completed_tasks += [here];
            print("Found Completed task: " + here.title);
        }
    }
}

walker:protect GetTask {
    can fetch with Task entry {
        report here;
    }
}

# Define a walker to mark tasks as complete
walker:protect CompleteTask {
    has title: str;

    can search with Root entry {
        visit [-->];
    }

    can mark_complete with Task entry {
        if here.title == self.title {
            here.completed = True;
            print("Completed task: " + here.title);
        }
    }
}

"""Function to add two numbers together."""
def:protect add_numbers(a: int, b: int) -> int {
    return a + b;
}

"""Function to generate a greeting message.

`def:pub` because `client_page` below calls it: only an endpoint bridges over
RPC, and a plain `def` would leave the client bundle naming a function it
never binds.
"""
def:pub greet(name: str = "World") -> str {
    return "Hello, " + name + "!";
}

glob _UNSET: object = object();

obj EchoBox {
    has hits: int = 0;
}

"""Optional parameters of each kind, echoed so a caller sees what each received.

`tags` and `box` are changed so a shared default would show up on the next call.
`limit` and `grid` have no plain JSON form. `marker` is a sentinel, so it must
reach the function as the same object, not a copy.
"""
def:pub echo_defaults(
    count: int = 5,
    ratio: float = 0.5,
    flag: bool = False,
    title: str = "seed",
    tags: list[str] = [],
    note: str | None = None,
    box: EchoBox = EchoBox(),
    limit: float = float("inf"),
    grid: dict[tuple[int, int], str] = {(1, 2): "x"},
    pairs: tuple[list[str]] = ([], ),
    marker: object = _UNSET
) -> dict[str, any] {
    tags.append("seen");
    box.hits += 1;
    pairs[0].append("seen");
    return {
        "count": count,
        "ratio": ratio,
        "flag": flag,
        "title": title,
        "tags": tags,
        "note": note,
        "hits": box.hits,
        "limit": limit,
        "grid": grid,
        "pairs": pairs,
        "unset": marker is _UNSET
    };
}

glob WELCOME_TITLE: str = "Runtime Test";

def:pub client_page -> JsxElement {
    <section class="welcome">
        <h1>{WELCOME_TITLE}</h1>
        <p>{greet()}</p>
    </section>
}
