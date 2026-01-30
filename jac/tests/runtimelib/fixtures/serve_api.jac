"""Example Jac program for REST API server."""

cl import from "@jac/runtime" { renderJsxTree, }

# Define some nodes
node Task {
    has title: str;
    has completed: bool = False;
    has priority: int = 0;
}

node User {
    has name: str;
    has email: str;
}

# Define a walker to create tasks
walker CreateTask {
    has title: str;
    has priority: int = 1;

    can create with `root entry {
        task_list = here ++> Task(title=self.title, priority=self.priority);
        task = task_list[0];
        if task {
            print("Created task: " + task.title);
            report task ;
        }
        root spawn CompleteTask(title=self.title);
    }
}

# Define a walker to list all tasks
walker ListTasks {
    has tasks: list = [];

    can collect with `root entry {
        visit [-->];
        completed_tasks_walker = root spawn ListCompletedTasks();
        report completed_tasks_walker.completed_tasks;
    }

    can gather with Task entry {
        print("Found task: " + here.title);
    }
}

# Define a walker to List completed Tasks
walker ListCompletedTasks {
    has completed_tasks: list = [];

    can collect with `root entry {
        visit [-->];
    }
    can gather with Task entry {
        if here.completed {
            self.completed_tasks += [here];
            print("Found Completed task: " + here.title);
        }
    }
}

walker GetTask {
    can fetch with Task entry {
        return here;
    }
}

# Define a walker to mark tasks as complete
walker CompleteTask {
    has title: str;

    can search with `root entry {
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
def add_numbers(a: int, b: int) -> int {
    return a + b;
}

"""Function to generate a greeting message."""
def greet(name: str = "World") -> str {
    return "Hello, " + name + "!";
}

cl glob WELCOME_TITLE: str = "Runtime Test";

cl def client_page() {
    return <section class="welcome">
        <h1>
            {WELCOME_TITLE}
        </h1>
        <p>
            {greet()}
        </p>
    </section>;
}
