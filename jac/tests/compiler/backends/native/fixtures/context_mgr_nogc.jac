"""Context cleanup under the slot-exception / explicit-ownership pathway."""
obj Tracker {
    has entered: int = 0,
        exited: int = 0;

    def __enter__ -> &mut Tracker {
        self.entered += 1;
        return self;
    }

    def __exit__(kind: &str, value: &str, trace: &str) -> bool {
        self.exited += 1;
        return False;
    }
}

def inner(t: &mut Tracker) -> int {
    with t {
        return 7;
    }
    return 0;
}

def normal -> int {
    t = Tracker();
    with t as alias {
        alias.entered += 10;
    }
    return t.entered * 10 + t.exited;
}

def returning -> int {
    t = Tracker();
    result = inner(&mut t);
    return result * 100 + t.exited;
}

def looping -> int {
    t = Tracker();
    for i in range(3) {
        with t {
            if i < 2 {
                continue;
            }
            break;
        }
    }
    return t.exited;
}

def throwing -> int {
    a = Tracker();
    b = Tracker();
    try {
        with a, b {
            raise ValueError("body");
        }
    } except ValueError {
        return a.exited * 10 + b.exited;
    }
    return -1;
}


def file_context(path: &str) -> int {
    with open(path, "wb") as stream {
        stream.write(b"closed");
    }
    with open(path, "rb") as stream {
        data = stream.read();
    }
    return len(data);
}
