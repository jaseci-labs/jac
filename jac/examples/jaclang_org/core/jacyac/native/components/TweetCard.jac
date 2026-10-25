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

impl time_ago(stamp: str) -> str {
    if not stamp {
        return "";
    }
    diff_ms = Date.now() - new(Date, stamp).getTime();
    minutes = int(diff_ms / 60000);
    hours = int(minutes / 60);
    days = int(hours / 24);
    if minutes < 1 {
        return "now";
    }
    if hours < 1 {
        return str(minutes) + "m";
    }
    if days < 1 {
        return str(hours) + "h";
    }
    if days < 30 {
        return str(days) + "d";
    }
    return stamp[0:10];
}
