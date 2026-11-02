def:pub Composer(
    avatar: str,
    avatarAlt: str,
    placeholder: str,
    value: str,
    onChange: Callable[[str], None],
    onPost: Callable[[], None],
    busy: bool = False,
    rows: int = 3,
    buttonLabel: str = "Post",
    showCharRing: bool = False,
) -> JsxElement;
