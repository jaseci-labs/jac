def:pub handle_of(username: str) -> str {
    return username.split("@")[0] if "@" in username else username;
}

def:pub initial_of(name: str) -> str {
    return name[0].upper() if name else "?";
}

def:pub count_label(count: int, one: str, many: str) -> str {
    return str(count) + " " + (one if count == 1 else many);
}
