glob hits: list[int] = [];

def hello -> None {
    hits.append(1);
}

def fire(f: Callable) -> None {
    f();
}

with entry {
    fire(hello);
    fire(hello);
    print(len(hits));
}
