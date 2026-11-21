"""A str passed to a C function, borrowed or owned, with an RC dump at exit."""

import from c { def strchr(text: str, character: i32) -> ptr[u8];  }

def find_dot(value: str) -> int {
    return 1 if strchr(value, i32(46)) else 0;
}

def run -> int {
    total = 0;
    for i in range(50) {
        for part in f"a.b{i}".split(".") {
            total += find_dot(part);
        }
        total += find_dot("x." + str(i));
        total += 1 if strchr("y." + str(i), i32(46)) else 0;
    }
    return total;
}

with entry {
    print(run());
    __rc_collect_cycles();
    __rc_debug_enable();
}
