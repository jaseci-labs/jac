import from "@jac/mobui" { View, Text, Pressable, TextInput }

def time_ago(stamp: str) -> str;

def:pub TweetCard(
    avatars: dict[str, str],
    tweet: Tweet,
    myUsername: str,
    onLike: Callable[[str], None],
    onComment: Callable[[str, str], bool],
    onDelete: Callable[[str], None],
) -> JsxElement;
