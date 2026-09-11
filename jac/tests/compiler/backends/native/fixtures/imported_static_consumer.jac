import from .imported_static_owner { Counter }

def answer -> int {
    return Counter.VALUE;
}
