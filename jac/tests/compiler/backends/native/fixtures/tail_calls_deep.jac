"""Ten million frames of mutual recursion and C-style dispatch loops.

Every call below is `return tail`, so each one reuses its caller's frame and
the stack stays flat however deep the recursion goes. As plain calls these
overflow any stack a process starts with. The dispatch goes through C
function pointers both to C definitions and to Jac functions a C data table
holds.
"""

import from c {
    obj Frame {
        has step: Callable[[i64, i64, ptr[Frame]], i64],
            halt: Callable[[i64, i64, ptr[Frame]], i64];
    }  def op_step(n: i64, acc: i64, frame: ptr[Frame]) -> i64 {
        if n == i64(0) {
            return tail frame.view(1)[0].halt(n, acc, frame);
        }
        return tail frame.view(1)[0].step(n - i64(1), acc + i64(3), frame);
    }  def op_halt(n: i64, acc: i64, frame: ptr[Frame]) -> i64 {
        return acc;
    }  def malloc(size: u64) -> ptr[Frame];  def free(p: ptr[Frame]);
}

import from c {
    obj Relay {
        has hop: Callable[[i64, i64], i64];
    }  glob relays: list[Relay] = [Relay(hop=relay_hop)];
}

# A Jac function C reaches through a function pointer.
def relay_hop(n: i64, acc: i64) -> i64 {
    if n == i64(0) {
        return acc;
    }
    table: ptr[Relay] = addressof(relays);
    return tail table.view(1)[0].hop(n - i64(1), acc + i64(5));
}

def ping(n: int, acc: int) -> int {
    if n == 0 {
        return acc;
    }
    return tail pong(n - 1, acc + 1);
}

def pong(n: int, acc: int) -> int {
    if n == 0 {
        return acc;
    }
    return tail ping(n - 1, acc + 2);
}

with entry {
    print(ping(10000000, 0));
    frame = malloc(u64(16));
    frame.view(1)[0].step = op_step;
    frame.view(1)[0].halt = op_halt;
    print(op_step(i64(10000000), i64(0), frame));
    free(frame);
    print(relay_hop(i64(10000000), i64(0)));
}
