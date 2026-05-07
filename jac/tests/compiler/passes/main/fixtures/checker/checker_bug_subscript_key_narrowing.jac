obj Item { has value: str = ""; }
obj Other { has code: int = 0; }

obj Segment {
    has start: int | None = None,
        end: int | None = None;
}

def check_first(items: list[Item | Other]) -> str {
    if isinstance(items[0], Item) {
        return items[0].value;  # ok: int literal index narrowed
    }
    return "";
}

def check_last(items: list[Item | Other]) -> str {
    if isinstance(items[-1], Item) {
        return items[-1].value;  # ok: negative int literal index narrowed
    }
    return "";
}

def check_host(config: dict[str, Item | Other]) -> str {
    if isinstance(config["host"], Item) {
        return config["host"].value;  # ok: string literal key narrowed
    }
    return "";
}

def segment_length(items: list[Segment]) -> int {
    if items[0].start is not None and items[0].end is not None {
        return items[0].end - items[0].start;  # ok: items[0].start and items[0].end narrowed to int
    }
    return 0;
}

def first_start(items: list[Segment]) -> int {
    if items[0].start is not None {
        return items[0].start;  # ok: items[0].start narrowed to int
    }
    return -1;
}
