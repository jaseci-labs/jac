def:pub post_limit -> int {
    return 280;
}

def:pub chars_left(text: str) -> int {
    return post_limit() - len(text);
}

def:pub valid_post(text: str) -> bool {
    return bool(text.strip()) and chars_left(text) >= 0;
}
