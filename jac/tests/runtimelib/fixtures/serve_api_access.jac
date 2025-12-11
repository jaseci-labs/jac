"""Test fixture for access level-based authentication."""

# Public functions (no authentication required)
def : pub public_function(
    name: str = "World"
) -> str {
    return f"Hello, {name}! (public)";
}

def : pub public_add(a: int, b: int) -> int {
    return a + b;
}

# Protected functions (authentication required)
def : protect protected_function(
    message: str
) -> str {
    return f"Protected: {message}";
}

# Private functions (authentication required)
def : priv private_function(
    secret: str
) -> str {
    return f"Private: {secret}";
}

# Node for walker tests
node Task {
    has title: str;
    has completed: bool = False;
}

# Public walker (no authentication required)
walker : pub PublicWalker {
    has message: str = "public";

    can enter with `root entry {
        report "Public walker executed: " + self.message ;
    }
}

# Protected walker (authentication required)
walker : protect ProtectedWalker {
    has data: str;

    can enter with `root entry {
        tasks = here ++> Task(title=self.data);
        report "Protected walker created task: " + tasks[0].title
        if tasks
        else "no task" ;
    }
}

# Private walker (authentication required)
walker : priv PrivateWalker {
    has secret: str;

    can enter with `root entry {
        report "Private walker with secret: " + self.secret ;
    }
}
