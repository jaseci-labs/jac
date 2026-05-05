"""Fixture for jac check diagnostic-snippet rendering test.

Triggers W0062 (deprecated `root()`) inside a traversal expression that
contains square brackets. The rendered source line in the diagnostic must
preserve the full bracketed text (`[root()-->][?:Task]`) — the console
must not interpret it as Rich markup.
"""

node Task {
    has title: str = "";
}

with entry {
    x = [root()-->][?:Task];
    print(x);
}
