import from "@jac/mobui" { View, Pressable, TextInput, ScrollView, RefreshControl }

def:pub FeedScreen(
    avatars: dict[str, str],
    username: str,
    composerText: str,
    onComposerChange: Callable[[str], None],
    onPost: Callable[[], None],
    posting: bool,
    searchQuery: str,
    onSearchChange: Callable[[str], None],
    onSearch: Callable[[], None],
    onClearSearch: Callable[[], None],
    loading: bool,
    refreshing: bool,
    onRefresh: Callable[[], None],
    tweets: list[Tweet],
    onLike: Callable[[str], None],
    onComment: Callable[[str, str], bool],
    onDelete: Callable[[str], None],
) -> JsxElement;
