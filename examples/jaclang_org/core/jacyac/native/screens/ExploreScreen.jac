import from "@jac/mobui" { View, Text, Pressable, ScrollView }

def ExploreScreen(
    avatars: dict[str, str],
    profiles: list[Profile],
    followingIds: list[str],
    myProfileId: str,
    trending: list[TrendingTag],
    loading: bool,
    onFollow: Callable[[str], Coroutine[any, any, None]],
    onUnfollow: Callable[[str], Coroutine[any, any, None]],
    onTrendPress: Callable[[str], Coroutine[any, any, None]],
) -> JsxElement;
