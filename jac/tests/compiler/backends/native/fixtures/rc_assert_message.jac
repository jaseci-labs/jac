"""Computed assertion messages under the RC trace.

Each shape fails an assertion whose message is worked out at run time and
catches the error: bound to a name or not, with a message that is not a
string, or with a slice of a string it built. Run from a `--debug` build,
every allocation made while the trace is on must be freed by the time it is
switched off.
"""

def unnamed(i: int) -> int {
    try {
        assert i < 0 , "bad " + str(i);
    } except AssertionError {
        return 1;
    }
    return 0;
}

def named(i: int) -> int {
    try {
        assert i < 0 , "bad " + str(i);
    } except AssertionError as error {
        return 1 if str(error).startswith("bad ") else 0;
    }
    return 0;
}

def listed(i: int) -> int {
    try {
        assert i < 0 , [str(i), "bad"];
    } except AssertionError {
        return 1;
    }
    return 0;
}

def sliced(text: str) -> int {
    try {
        assert False , text[1:];
    } except AssertionError {
        return 1;
    }
    return 0;
}

with entry {
    total = 0;
    __rc_debug_enable();
    for i in range(3) {
        total += unnamed(i) + named(i) + listed(i) + sliced("x" + str(i) + "yz");
    }
    __rc_debug_disable();
    print(total);
}
