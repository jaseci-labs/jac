obj Item { has value: str = ""; }
obj Other { has code: int = 0; }

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
