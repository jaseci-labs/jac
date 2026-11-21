import from "lucide-react" { Inbox }

def:pub FeedTab(
    showWelcome: bool,
    onDismissWelcome: Callable[[], None],
    profileAvatar: str,
    profileUsername: str,
    composerText: str,
    onComposerChange: Callable[[str], None],
    onPost: Callable[[], Coroutine[any, any, None]],
    feedLoading: bool,
    posting: bool,
    tweets: list[Tweet],
    avatars: dict[str, str],
    onViewProfile: Callable[[str], Coroutine[any, any, None]],
    onLike: Callable[[str], Coroutine[any, any, None]],
    onComment: Callable[[str, str], Coroutine[any, any, bool]],
    onDelete: Callable[[str], Coroutine[any, any, None]],
    onRepost: Callable[[str, str, str], None],
) -> JsxElement;
