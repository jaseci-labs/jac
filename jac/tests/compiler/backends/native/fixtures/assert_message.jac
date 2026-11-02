def check(x: int) {
    assert x > 0 , "x must be positive: " + str(x);
}

def named(word: str) {
    assert len(word) > 3 , f"too short: {word}";
}

def plain(x: int) {
    assert x > 0 , "a literal";
}

def bare(x: int) {
    assert x > 0;
}

def computed_message -> str {
    try {
        check(-1);
    } except AssertionError as error {
        return str(error);
    }
    return "held";
}

def formatted_message -> str {
    try {
        named("ab");
    } except AssertionError as error {
        return str(error);
    }
    return "held";
}

def literal_message -> str {
    try {
        plain(0);
    } except AssertionError as error {
        return str(error);
    }
    return "held";
}

def bare_message -> str {
    try {
        bare(0);
    } except AssertionError as error {
        return str(error);
    }
    return "held";
}

def holding -> int {
    check(5);
    named("long enough");
    plain(1);
    bare(1);
    return 1;
}

def counted(calls: list[int]) -> str {
    calls.append(1);
    return "counted";
}

def watched(x: int, calls: list[int]) {
    assert x > 0 , counted(calls);
}

def message_calls -> int {
    calls: list[int] = [];
    watched(1, calls);
    watched(2, calls);
    held = len(calls);
    try {
        watched(0, calls);
    } except AssertionError {}
    return held * 10 + len(calls);
}

def nothing(x: int) {
    assert x > 0 , None;
}

def none_message -> str {
    try {
        nothing(0);
    } except AssertionError as error {
        return str(error);
    }
    return "held";
}
