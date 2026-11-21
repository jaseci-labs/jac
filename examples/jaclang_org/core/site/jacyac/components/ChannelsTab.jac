import from "lucide-react" { Hash, Users, Plus, ArrowLeft }

def:pub ChannelsTab(
    channels: list[ChannelBundle],
    channelsLoading: bool,
    selectedChannel: ChannelBundle | None,
    channelPosts: list[Tweet],
    profileAvatar: str,
    profileUsername: str,
    onCreateChannel: Callable[[str, str], Coroutine[any, any, None]],
    onJoinChannel: Callable[[str], Coroutine[any, any, None]],
    onLeaveChannel: Callable[[str], Coroutine[any, any, None]],
    onSelectChannel: Callable[[str], Coroutine[any, any, None]],
    onChannelPost: Callable[[str], Coroutine[any, any, bool]],
    onBackToChannels: Callable[[], None],
    avatars: dict[str, str],
    onViewProfile: Callable[[str], Coroutine[any, any, None]],
    onLike: Callable[[str], Coroutine[any, any, None]],
    onComment: Callable[[str, str], Coroutine[any, any, bool]],
    onDelete: Callable[[str], Coroutine[any, any, None]],
    onRepost: Callable[[str, str, str], None],
) -> JsxElement;
