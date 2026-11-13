"""`__list_data_ptr` refusals: each function is refused (E5095) and so stays
Python-only."""

obj Cell {
    has v: int = 0;
}

def make -> list[int] {
    return [1, 2, 3];
}

"""A list of objects: a raw store would bypass the elements' counts."""
def objects_list -> int {
    cells: list[Cell] = [Cell(v=1)];
    return __list_data_ptr(cells);
}

def str_list -> int {
    names: list[str] = ["a"];
    return __list_data_ptr(names);
}

"""A temporary list: released at the end of the statement, buffer and all."""
def call_result -> int {
    return __list_data_ptr(make());
}

def literal_list -> int {
    return __list_data_ptr([1, 2, 3]);
}
