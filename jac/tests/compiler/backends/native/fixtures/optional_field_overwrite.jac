"""Overwriting an optional object field while other references to the old
object are still alive. Each surviving reference has to keep the object
alive: a module global, a function local, a list element and another
object's field. The module-level (`with entry`) names are module globals, whose
optional store never retained what it read, so the field's overwrite freed
the object they still pointed at."""

obj Grid {
    has bounds: list[int] = [0, 0, 0];
}

obj Holder {
    has grid: Grid | None = None;
}

def show(label: str, grid: Grid | None) {
    if grid is not None {
        print(label, grid.bounds);
    } else {
        print(label, None);
    }
}

def in_function {
    holder = Holder(grid=Grid(bounds=[1, 2, 3]));
    kept = holder.grid;
    holder.grid = None;
    show("local after clear", kept);
    holder.grid = Grid(bounds=[4, 5, 6]);
    again = holder.grid;
    holder.grid = Grid(bounds=[7, 8, 9]);
    show("local after replace", again);
}

glob saved: Grid | None = None;

def stash(holder: Holder) {
    saved = holder.grid;
}

with entry {
    holder = Holder(grid=Grid(bounds=[5, 6, 7]));
    kept = holder.grid;
    holder.grid = None;
    show("global after clear", kept);

    holder.grid = Grid(bounds=[1, 1, 1]);
    replaced = holder.grid;
    holder.grid = Grid(bounds=[2, 2, 2]);
    show("global after replace", replaced);

    holder.grid = kept;
    holder.grid = None;
    holder.grid = kept;
    show("restored", holder.grid);
    holder.grid = holder.grid;
    show("self-assigned", holder.grid);

    listed: list[Grid | None] = [holder.grid];
    other = Holder(grid=holder.grid);
    stash(holder);
    holder.grid = None;
    show("list element", listed[0]);
    show("other field", other.grid);
    show("glob via function", saved);
    show("kept", kept);

    in_function();
}
