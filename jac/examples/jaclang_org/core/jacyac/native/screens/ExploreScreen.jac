import from "@jac/mobui" { View, Text, Pressable, ScrollView }

def:pub ExploreScreen(
    avatars: dict[str, str],
    profiles: list[Profile],
    followingIds: list[str],
    myProfileId: str,
    trending: list[TrendingTag],
    loading: bool,
    onFollow: Callable[[str], None],
    onUnfollow: Callable[[str], None],
    onTrendPress: Callable[[str], None],
) -> JsxElement;
