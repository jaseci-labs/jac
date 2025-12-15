import from bar { bar_walk }
import from jaclang { JacRuntime }
import os;

def update_bar_walker {
    "Updating bar.jac with new behavior." |> print;
    (bar_walk_new, ) = JacRuntime.update_walker("bar", items={'bar_walk': None});
    "Running bar_walk after update..." |> print;
    root spawn bar_walk_new();
    print(f"bar_walk: {bar_walk_new.__dict__}");
}

with entry {
    update_bar_walker();
}
