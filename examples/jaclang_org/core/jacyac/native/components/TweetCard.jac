import from "@jac/mobui" { View, Text, Pressable, TextInput }

def time_ago(stamp: str) -> str;

def TweetCard(
    avatars: dict[str, str],
    tweet: Tweet,
    myUsername: str,
    onLike: Callable[[str], Coroutine[any, any, None]],
    onComment: Callable[[str, str], Coroutine[any, any, bool]],
    onDelete: Callable[[str], Coroutine[any, any, None]],
) -> JsxElement;
