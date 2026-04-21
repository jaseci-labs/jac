import from collections.abc { Generator, Iterator, Iterable }

def gen_ok -> Generator[int, None, None] {
    yield 1;
    yield 2;
    return;
}

def gen_return_str -> Generator[int, None, str] {
    yield 1;
    return "done";
}

def iter_ok -> Iterator[int] {
    yield 1;
    return;
}

def iterable_ok -> Iterable[int] {
    yield 42;
}

def accumulator -> Generator[int, int, str] {
    total = 0;
    while True {
        x = yield total;
        if x is None {
            break;
        }
        total += x;
    }
    return f"Final total: {total}";
}

def bad_yield -> Generator[int, None, None] {
    yield "hello";
}

def bad_return -> Generator[int, None, str] {
    yield 1;
    return 42;
}

glob _ = list(gen_ok()),
     _ = gen_return_str(),
     _ = list(iter_ok()),
     _ = list(iterable_ok()),
     _ = accumulator();
