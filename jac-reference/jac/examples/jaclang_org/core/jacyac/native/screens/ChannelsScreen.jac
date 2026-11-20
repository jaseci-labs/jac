import from "@jac/mobui" { View, Text, Pressable, TextInput, ScrollView, Modal }

def ChannelDetail(
    avatars: dict[str, str],
    channel: ChannelBundle,
    posts: list[Tweet],
    username: str,
    onBack: Callable[[], None],
    onJoin: Callable[[str], None],
    onLeave: Callable[[str], None],
    onPost: Callable[[str], bool],
    onLike: Callable[[str], None],
    onComment: Callable[[str, str], bool],
    onDelete: Callable[[str], None],
) -> JsxElement;

def:pub ChannelsScreen(
    avatars: dict[str, str],
    channels: list[ChannelBundle],
    loading: bool,
    selected: ChannelBundle | None,
    posts: list[Tweet],
    username: str,
    onCreate: Callable[[str, str], None],
    onJoin: Callable[[str], None],
    onLeave: Callable[[str], None],
    onSelect: Callable[[str], None],
    onBack: Callable[[], None],
    onPost: Callable[[str], bool],
    onLike: Callable[[str], None],
    onComment: Callable[[str, str], bool],
    onDelete: Callable[[str], None],
) -> JsxElement;
