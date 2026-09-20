"""Owned native values survive errors and release on every exit."""
import from jaclang.runtime.cpython.references { ObjectResult, borrowed_result }

def fail {
    raise ValueError("native failure");
}

def inner(value: u64) -> ObjectResult {
    held = borrowed_result(value);
    fail();
    return held;
}

def:pub unwind(value: u64) {
    try {
        result = inner(value);
    } except ValueError {}
}

def held_stream(value: u64) -> Iterator[int] {
    held = borrowed_result(value);
    yield 1;
    fail();
    yield 2;
}

def:pub unwind_generator(value: u64) -> int {
    total = 0;
    try {
        for item in held_stream(value) {
            total += item;
        }
    } except ValueError {
        total += 10;
    }
    return total;
}

def rethrow_stream -> Iterator[int] {
    try {
        fail();
    } except ValueError {
        yield 1;
        raise;
    }
}

def finally_stream -> Iterator[int] {
    try {
        fail();
    } finally {
        yield 1;
    }
}

def:pub unwind_suspended_handler -> int {
    total = 0;
    try {
        for item in rethrow_stream() {
            total += item;
        }
    } except ValueError {
        total += 10;
    }
    return total;
}

def:pub unwind_suspended_finally -> int {
    total = 0;
    try {
        for item in finally_stream() {
            total += item;
        }
    } except ValueError {
        total += 10;
    }
    return total;
}

obj FailingIter {
    has value: u64,
        position: int = 0;

    def __iter__ -> FailingIter {
        return self;
    }

    def __next__ -> int {
        held = borrowed_result(self.value);
        if self.position == 0 {
            self.position += 1;
            return 1;
        }
        fail();
        return 0;
    }
}

def:pub unwind_iterator(value: u64) -> int {
    total = 0;
    try {
        for item in FailingIter(value=value) {
            total += item;
        }
    } except ValueError {
        total += 10;
    }
    return total;
}

def:pub unwind_map(value: u64) -> int {
    def convert(item: int) -> int {
        held = borrowed_result(value);
        if item == 2 {
            fail();
        }
        return item;
    }
    total = 0;
    try {
        for item in map(convert, [1, 2, 3]) {
            total += item;
        }
    } except ValueError {
        total += 10;
    }
    return total;
}

def consume(first: ObjectResult, second: int) {}

def fail_int -> int {
    fail();
    return 0;
}

def:pub unwind_argument(value: u64) {
    try {
        consume(borrowed_result(value), fail_int());
    } except ValueError {}
}

obj PayloadError(Exception) {
    has held: ObjectResult;
}

def fail_payload(value: u64) {
    raise PayloadError(held=borrowed_result(value));
}

def:pub unwind_payload(value: u64) {
    try {
        fail_payload(value);
    } except PayloadError {}
}

def:pub unwind_payload_bound(value: u64) {
    try {
        fail_payload(value);
    } except PayloadError as error {
        assert error.held is not None;
    }
}

def fail_message(number: int) {
    message = "error " + str(number);
    raise ValueError(message);
}

def:pub unwind_message -> bool {
    try {
        fail_message(42);
    } except ValueError as error {
        return str(error) == "error 42";
    }
    return False;
}

def payload_stream(value: u64) -> Iterator[int] {
    try {
        fail_payload(value);
    } except PayloadError {
        yield 1;
        raise;
    }
}

def:pub unwind_payload_generator(value: u64) -> int {
    total = 0;
    try {
        for item in payload_stream(value) {
            total += item;
        }
    } except PayloadError {
        total += 10;
    }
    return total;
}

obj Incomplete {
    has held: ObjectResult,
        number: int;
}

obj FailedInitializer {
    has held: ObjectResult;

    def init(value: u64) {
        self.held = borrowed_result(value);
        fail();
    }
}

def:pub unwind_constructor(value: u64) {
    try {
        item = Incomplete(held=borrowed_result(value), number=fail_int());
    } except ValueError {}
}

def:pub unwind_initializer(value: u64) {
    try {
        item = FailedInitializer(value);
    } except ValueError {}
}

def fail_result -> ObjectResult {
    fail();
    return borrowed_result(0);
}

def:pub unwind_list(value: u64) {
    try {
        items = [borrowed_result(value), fail_result()];
    } except ValueError {}
}

def cancelled_return(value: u64) -> ObjectResult {
    try {
        return borrowed_result(value);
    } finally {
        fail();
    }
}

def:pub unwind_return(value: u64) {
    try {
        item = cancelled_return(value);
    } except ValueError {}
}

glob test_witness: u64 = 0;

def:pub set_test_witness(value: u64) {
    test_witness = value;
}

test "failing owned payload" {
    fail_payload(test_witness);
}
