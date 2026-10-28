import from "lucide-react" { Inbox }

def:pub FeedTab(
    showWelcome: bool,
    onDismissWelcome: Callable[[], None],
    profileAvatar: str,
    profileUsername: str,
    composerText: str,
    onComposerChange: Callable[[str], None],
    onPost: Callable[[], None],
    feedLoading: bool,
    posting: bool,
    tweets: list[Tweet],
    avatars: dict[str, str],
    onViewProfile: Callable[[str], None],
    onLike: Callable[[str], None],
    onComment: Callable[[str, str], bool],
    onDelete: Callable[[str], None],
    onRepost: Callable[[str, str, str], None],
) -> JsxElement;
