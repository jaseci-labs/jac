import from "@jac/mobui" { View, Text, Pressable, TextInput, ScrollView }

def ProfileScreen(
    avatars: dict[str, str],
    profile: ProfileBundle | None,
    editing: bool,
    saving: bool,
    error: str,
    bioText: str,
    onBioChange: Callable[[str], None],
    onSaveBio: Callable[[], Coroutine[any, any, None]],
    onStartEdit: Callable[[], None],
    onCancelEdit: Callable[[], None],
    onLogout: Callable[[], Coroutine[any, any, None]],
    onLike: Callable[[str], Coroutine[any, any, None]],
    onComment: Callable[[str, str], Coroutine[any, any, bool]],
    onDelete: Callable[[str], Coroutine[any, any, None]],
) -> JsxElement;
