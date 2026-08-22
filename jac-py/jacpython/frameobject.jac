# P3.2d — frame ownership / lineno helpers.
# Lift: Objects/_lifted/frameobject_core.jac

glob FRAME_OWNED_BY_THREAD: int = 0,
     FRAME_OWNED_BY_GENERATOR: int = 1;

def frame_owned_by_generator(owner: int) -> bool {
    return owner == FRAME_OWNED_BY_GENERATOR;
}

def frame_owned_by_thread(owner: int) -> bool {
    return owner == FRAME_OWNED_BY_THREAD;
}

def frame_lineno_valid(lineno: int) -> bool {
    return lineno >= 0;
}

def frame_stack_empty(stacktop: int) -> bool {
    return stacktop <= 0;
}
