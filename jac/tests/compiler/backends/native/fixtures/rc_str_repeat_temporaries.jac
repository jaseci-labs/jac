"""String repeat temporaries under the RC trace.

Each shape builds a `s * n` buffer, from a borrowed or an owned operand, and
drops it before returning. Run from a `--debug` build, every `str_concat` and
`str_repeat` allocation made while the trace is on must be freed by the time
it is switched off.
"""

def inline_result(base: str) -> int {
    return len(base * 2);
}

def local_result(base: str) -> int {
    doubled = base * 2;
    return len(doubled);
}

def owned_left_operand(base: str, i: int) -> int {
    return len((base + str(i)) * 3);
}

def owned_right_operand(base: str, i: int) -> int {
    return len(2 * (str(i) + base));
}

glob base = "abcd";
with entry {
    total = 0;
    __rc_debug_enable();
    for i in range(3) {
        total += inline_result(base) + local_result(base);
        total += owned_left_operand(base, i) + owned_right_operand(base, i);
    }
    __rc_debug_disable();
    print(total);
}
