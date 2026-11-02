import from "lucide-react" { Search, X, TrendingUp }

def:pub RightSidebar(
    searchQuery: str,
    onSearchChange: Callable[[str], None],
    onSearch: Callable[[str], None],
    onClearSearch: Callable[[], None],
    trendingTags: list[TrendingTag],
    onTrendClick: Callable[[str], None],
    toFollow: list[Profile],
    avatars: dict[str, str],
    onFollow: Callable[[str], None],
    onShowMore: Callable[[], None],
    onViewProfile: Callable[[str], None],
) -> JsxElement;
