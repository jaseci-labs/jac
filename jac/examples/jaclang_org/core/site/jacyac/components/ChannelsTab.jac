import from "lucide-react" { Hash, Users, Plus, ArrowLeft }

def:pub ChannelsTab(
    channels: list[ChannelBundle],
    channelsLoading: bool,
    selectedChannel: ChannelBundle | None,
    channelPosts: list[Tweet],
    profileAvatar: str,
    profileUsername: str,
    onCreateChannel: Callable[[str, str], None],
    onJoinChannel: Callable[[str], None],
    onLeaveChannel: Callable[[str], None],
    onSelectChannel: Callable[[str], None],
    onChannelPost: Callable[[str], bool],
    onBackToChannels: Callable[[], None],
    avatars: dict[str, str],
    onViewProfile: Callable[[str], None],
    onLike: Callable[[str], None],
    onComment: Callable[[str, str], bool],
    onDelete: Callable[[str], None],
    onRepost: Callable[[str, str, str], None],
) -> JsxElement;
