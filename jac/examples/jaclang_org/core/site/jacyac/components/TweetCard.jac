import from "lucide-react" { Heart, MessageCircle, Trash2, Repeat2, Send }

def:pub TweetCard(
    tweet: Tweet,
    myUsername: str,
    avatars: dict[str, str],
    onViewProfile: Callable[[str], None],
    onLike: Callable[[str], None],
    onComment: Callable[[str, str], bool],
    onDelete: Callable[[str], None],
    onRepost: Callable[[str, str, str], None],
) -> JsxElement;
