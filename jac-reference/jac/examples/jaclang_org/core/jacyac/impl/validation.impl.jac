impl post_limit -> int {
    return 280;
}

impl chars_left(text: str) -> int {
    return post_limit() - len(text);
}

impl valid_post(text: str) -> bool {
    return bool(text.strip()) and chars_left(text) >= 0;
}
