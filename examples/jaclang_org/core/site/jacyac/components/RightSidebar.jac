import from "lucide-react" { Search, X, TrendingUp }

def:pub RightSidebar(
    searchQuery: str,
    onSearchChange: Callable[[str], None],
    onSearch: Callable[[str], Coroutine[any, any, None]],
    onClearSearch: Callable[[], None],
    trendingTags: list[TrendingTag],
    onTrendClick: Callable[[str], Coroutine[any, any, None]],
    toFollow: list[Profile],
    avatars: dict[str, str],
    onFollow: Callable[[str], Coroutine[any, any, None]],
    onShowMore: Callable[[], Coroutine[any, any, None]],
    onViewProfile: Callable[[str], Coroutine[any, any, None]],
) -> JsxElement;
