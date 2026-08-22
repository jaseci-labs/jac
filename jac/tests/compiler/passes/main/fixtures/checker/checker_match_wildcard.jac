"""The match wildcard must not draw undefined-name or unknown-type noise (#7922)."""

def pick(x: str) -> str {
    match x {
        case "a":
            return "AAA";

        case _:
            return "OTHER";

    }
}

with entry {
    print(pick("a"));
}
