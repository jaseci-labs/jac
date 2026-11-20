import from "@jac/mobui" { View, Pressable, TextInput, ScrollView, RefreshControl }

def FeedScreen(
    avatars: dict[str, str],
    username: str,
    composerText: str,
    onComposerChange: Callable[[str], None],
    onPost: Callable[[], Coroutine[any, any, None]],
    posting: bool,
    searchQuery: str,
    onSearchChange: Callable[[str], None],
    onSearch: Callable[[], Coroutine[any, any, None]],
    onClearSearch: Callable[[], Coroutine[any, any, None]],
    loading: bool,
    refreshing: bool,
    onRefresh: Callable[[], Coroutine[any, any, None]],
    tweets: list[Tweet],
    onLike: Callable[[str], Coroutine[any, any, None]],
    onComment: Callable[[str, str], Coroutine[any, any, bool]],
    onDelete: Callable[[str], Coroutine[any, any, None]],
) -> JsxElement;
