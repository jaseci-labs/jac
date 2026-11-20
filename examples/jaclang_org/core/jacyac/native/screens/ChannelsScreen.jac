import from "@jac/mobui" { View, Text, Pressable, TextInput, ScrollView, Modal }

def ChannelDetail(
    avatars: dict[str, str],
    channel: ChannelBundle,
    posts: list[Tweet],
    username: str,
    onBack: Callable[[], None],
    onJoin: Callable[[str], Coroutine[any, any, None]],
    onLeave: Callable[[str], Coroutine[any, any, None]],
    onPost: Callable[[str], Coroutine[any, any, bool]],
    onLike: Callable[[str], Coroutine[any, any, None]],
    onComment: Callable[[str, str], Coroutine[any, any, bool]],
    onDelete: Callable[[str], Coroutine[any, any, None]],
) -> JsxElement;

def ChannelsScreen(
    avatars: dict[str, str],
    channels: list[ChannelBundle],
    loading: bool,
    selected: ChannelBundle | None,
    posts: list[Tweet],
    username: str,
    onCreate: Callable[[str, str], Coroutine[any, any, None]],
    onJoin: Callable[[str], Coroutine[any, any, None]],
    onLeave: Callable[[str], Coroutine[any, any, None]],
    onSelect: Callable[[str], Coroutine[any, any, None]],
    onBack: Callable[[], None],
    onPost: Callable[[str], Coroutine[any, any, bool]],
    onLike: Callable[[str], Coroutine[any, any, None]],
    onComment: Callable[[str, str], Coroutine[any, any, bool]],
    onDelete: Callable[[str], Coroutine[any, any, None]],
) -> JsxElement;
