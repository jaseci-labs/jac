# Context manager tests for native LLVM IR codegen.

# Custom context manager object for testing
obj Tracker {
    has enter_count: int = 0,
        exit_count: int = 0,
        value: int = 0;

    def __enter__ -> Tracker {
        self.enter_count = self.enter_count + 1;
        return self;
    }

    def __exit__(exc_type: str, exc_val: str, traceback: str) -> bool {
        self.exit_count = self.exit_count + 1;
        return False;
    }

    def set_value(v: int) {
        self.value = v;
    }

    def get_enter_count -> int {
        return self.enter_count;
    }

    def get_exit_count -> int {
        return self.exit_count;
    }

    def get_value -> int {
        return self.value;
    }
}

# Test 1: __enter__ is called
def test_with_enter -> int {
    t: Tracker = Tracker();
    with t {
        t.set_value(42);
    }
    return t.get_enter_count();
}

# Test 2: __exit__ is called
def test_with_exit -> int {
    t: Tracker = Tracker();
    with t {
        t.set_value(42);
    }
    return t.get_exit_count();
}

# Test 3: Body executes and value is set
def test_with_body -> int {
    t: Tracker = Tracker();
    with t {
        t.set_value(99);
    }
    return t.get_value();
}

# Test 4: with ... as var binding
def test_with_as_binding -> int {
    t: Tracker = Tracker();
    with t as ctx {
        ctx.set_value(77);
    }
    return t.get_value();
}

# Test 5: File context manager — write with auto-close
def test_file_context_manager -> int {
    with open("/tmp/jac_native_ctx_test.txt", "w") as f {
        f.write("context");
    }
    # File should be closed, read it back to verify
    f2: File = open("/tmp/jac_native_ctx_test.txt", "r");
    if f2 is None {
        return 0;
    }
    content: str = f2.read();
    f2.close();
    if content == "context" {
        return 1;
    }
    return 0;
}

# Test 6: Verify enter and exit both called exactly once
def test_with_enter_exit_once -> int {
    t: Tracker = Tracker();
    with t {
        t.set_value(10);
    }
    # enter_count * 100 + exit_count => should be 101
    return t.get_enter_count() * 100 + t.get_exit_count();
}

# Non-local exits must unwind acquired managers exactly once.
def return_inside(t: Tracker) -> int {
    with t {
        return 7;
    }
    return 0;
}

def test_with_return -> int {
    t = Tracker();
    result = return_inside(t);
    return result * 100 + t.exit_count;
}

def test_with_loop_control -> int {
    t = Tracker();
    for i in range(3) {
        with t {
            if i < 2 {
                continue;
            }
            break;
        }
    }
    return t.exit_count;
}

def test_with_raise -> int {
    t = Tracker();
    try {
        with t {
            raise ValueError("body");
        }
    } except ValueError {
        return t.exit_count;
    }
    return -1;
}

def test_with_nested_raise -> int {
    outer = Tracker();
    inner = Tracker();
    try {
        with outer, inner {
            raise ValueError("nested");
        }
    } except ValueError {
        return outer.exit_count * 10 + inner.exit_count;
    }
    return -1;
}

obj Suppressor(Tracker) {
    override def __exit__(exc_type: str, exc_val: str, traceback: str) -> bool {
        self.exit_count += 1;
        return True;
    }
}

def test_with_suppression -> int {
    t = Suppressor();
    with t {
        raise ValueError("suppressed");
    }
    return t.exit_count;
}

obj EnterFailure(Tracker) {
    override def __enter__ -> EnterFailure {
        raise ValueError("enter");
    }
}

def test_with_failed_enter -> int {
    outer = Tracker();
    inner = EnterFailure();
    try {
        with outer, inner {
            return -2;
        }
    } except ValueError {
        return outer.exit_count * 10 + inner.exit_count;
    }
    return -1;
}
