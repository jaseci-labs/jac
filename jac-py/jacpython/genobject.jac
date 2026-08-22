# P3.2d — generator state helpers.
# Lift: Objects/_lifted/genobject_core.jac

glob FRAME_CREATED: int = 0,
     FRAME_SUSPENDED: int = 1,
     FRAME_EXECUTING: int = 2,
     FRAME_COMPLETED: int = 3;

def gen_is_created(state: int) -> bool {
    return state == FRAME_CREATED;
}

def gen_is_suspended(state: int) -> bool {
    return state == FRAME_SUSPENDED;
}

def gen_is_executing(state: int) -> bool {
    return state == FRAME_EXECUTING;
}

def gen_is_completed(state: int) -> bool {
    return state == FRAME_COMPLETED;
}

def gen_gi_running(state: int) -> bool {
    return state == FRAME_EXECUTING;
}
