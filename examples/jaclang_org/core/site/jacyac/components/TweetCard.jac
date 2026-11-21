import from "lucide-react" { Heart, MessageCircle, Trash2, Repeat2, Send }

def:pub TweetCard(
    tweet: Tweet,
    myUsername: str,
    avatars: dict[str, str],
    onViewProfile: Callable[[str], Coroutine[any, any, None]],
    onLike: Callable[[str], Coroutine[any, any, None]],
    onComment: Callable[[str, str], Coroutine[any, any, bool]],
    onDelete: Callable[[str], Coroutine[any, any, None]],
    onRepost: Callable[[str, str, str], None],
) -> JsxElement;
