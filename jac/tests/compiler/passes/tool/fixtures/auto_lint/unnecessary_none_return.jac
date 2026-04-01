"""Fixture for W3037 auto-fix: unnecessary -> None return type."""

def no_return_with_none -> None {
    print("hello");
}

def has_return_with_none -> None {
    return None;
}

def no_return_with_type -> int {
    print("hello");
}

def with_params(x: int, y: str) -> None {
    print(x, y);
}

obj Foo {
    def method(self: Foo) -> None {
        print("method");
    }
}

def handler {
    lambda e: str -> None { print(e); };
    lambda x: int, y: int -> None { print(x + y); };
    lambda -> None { print("no params"); };
}
