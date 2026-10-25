def:pub handle_of(username: str) -> str;

def:pub initial_of(name: str) -> str;

def:pub count_label(count: int, one: str, many: str) -> str;

impl handle_of(username: str) -> str {
    return username.split("@")[0] if "@" in username else username;
}

impl initial_of(name: str) -> str {
    return name[0].upper() if name else "?";
}

impl count_label(count: int, one: str, many: str) -> str {
    return str(count) + " " + (one if count == 1 else many);
}

def:pub text_segments(text: str) -> list[dict[str, str]];
