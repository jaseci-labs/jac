import from jaclang { JacRuntime }
import from bar { bar_walk }
# Test runner to initialize the walker
def test_run {
    # Print the loaded modules
    modules = JacRuntime.list_modules();
    "Loaded Modules:" |> print;
    for mod_name in modules {
        f"Module: {mod_name}" |> print;
    }
    # Print walkers
    walkers = JacRuntime.list_walkers(mod_name);
    if walkers {
        f"Walkers in {mod_name}:" |> print;
        for walker in walkers {
            f"  - Walker: {walker}" |> print;
        }
    }
    # Print nodes
    nodes = JacRuntime.list_nodes(mod_name);
    if nodes {
        f"Nodes in {mod_name}:" |> print;
        for nd in nodes {
            f"  - Node: {nd}" |> print;
        }
    }
    # Print edges
    edges = JacRuntime.list_edges(mod_name);
    if edges {
        f"Edges in {mod_name}:" |> print;
        for edge in edges {
            f"  - Edge: {edge}" |> print;
        }
    }
    root spawn bar_walk();
}

# Define the entry point to run the test
with entry {
    test_run();
}
