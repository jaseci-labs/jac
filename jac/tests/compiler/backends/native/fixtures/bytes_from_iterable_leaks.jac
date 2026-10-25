"""`bytes` and `bytearray` over a range holding an int past 255, caught."""

def caught(i: int) -> int {
    try {
        made = bytes(range(250 + i % 3, 258));
        return len(made);
    } except ValueError {
        return -1;
    }
}

def caught_array(i: int) -> int {
    try {
        made = bytearray(range(253, 257 + i % 2));
        return len(made);
    } except ValueError {
        return -2;
    }
}

with entry {
    total = 0;
    for i in range(50) {
        total += caught(i) + caught_array(i);
    }
    print(total);
    __rc_collect_cycles();
    __rc_debug_enable();
}
