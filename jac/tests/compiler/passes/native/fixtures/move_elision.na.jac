obj Box { has v: int = 0; }

def take(x: Box) -> int {
    return 1;
}

# Each iteration: allocate a fresh owned Box, MOVE it a -> b (a bare-Name RHS
# bound to a proven-unique owned binding), then consume b. The move is lowered
# without an alias retain and nulls the source slot, so the object is freed
# exactly once (b's cleanup). A double free would corrupt the heap; a leak would
# grow RSS. Returns n so the caller can assert the loop ran to completion.
def run_moves(n: int) -> int {
    total = 0;
    i = 0;
    while i < n {
        a: own Box = Box(v=i);
        b = a;
        total = total + take(b);
        i = i + 1;
    }
    return total;
}
