def:pub name_of(display_name: str, username: str) -> str;

def:pub avatar_of(avatars: dict[str, str], username: str) -> str;

impl name_of(display_name: str, username: str) -> str {
    return display_name or handle_of(username);
}

impl avatar_of(avatars: dict[str, str], username: str) -> str {
    return avatars.get(username) or "";
}
