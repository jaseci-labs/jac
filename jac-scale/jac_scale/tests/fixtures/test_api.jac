"""Test API fixture for jac-scale serve tests."""

# ============================================================================
# Test Functions
# ============================================================================
def add_numbers(
    a: int, b: int
) -> int {
    return a + b;
}

def greet(name: str = "World") -> str {
    return "Hello, " + name + "!";
}

def multiply(x: int, y: int) -> int {
    return x * y;
}

# ============================================================================
# Test Data Models
# ============================================================================
node Task {
    has title: str;
    has priority: int = 1;
    has completed: bool = False;
}

node TaskList {
    has name: str = "My Tasks";
}

# ============================================================================
# Test Walkers
# ============================================================================
walker CreateTask {
    has title: str;
    has priority: int = 1;

    can create with `root entry {
        new_task = here ++> Task(title=self.title, priority=self.priority);
        report new_task ;
    }
}

walker ListTasks {
    can list with `root entry {
        tasks = [-->];
        report tasks ;
    }
}

walker CompleteTask {
    has title: str;

    can complete with `root entry {
        for task in [-->] {
            if task.title == self.title {
                visit task;
            }
        }
    }

    can mark_done with Task entry {
        here.completed = True;
        report here ;
    }
}

walker GetTask {
    can get with Task entry {
        report here ;
    }
}

walker : priv PrivateCreateTask {
    has title: str;
    has priority: int = 1;

    can create with `root entry {
        new_task = here ++> Task(title=self.title, priority=self.priority);
        report {"message": "Private task created", "task": new_task} ;
    }
}

walker : pub PublicInfo {
    can get_info with `root entry {
        report {"message": "This is a public endpoint", "auth_required": False} ;
    }
}
