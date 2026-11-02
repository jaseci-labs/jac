import from "@jac/mobui" { View, Text, Pressable, TextInput, ScrollView }

def:pub ProfileScreen(
    avatars: dict[str, str],
    profile: ProfileBundle | None,
    editing: bool,
    saving: bool,
    error: str,
    bioText: str,
    onBioChange: Callable[[str], None],
    onSaveBio: Callable[[], None],
    onStartEdit: Callable[[], None],
    onCancelEdit: Callable[[], None],
    onLogout: Callable[[], None],
    onLike: Callable[[str], None],
    onComment: Callable[[str, str], bool],
    onDelete: Callable[[str], None],
) -> JsxElement;
