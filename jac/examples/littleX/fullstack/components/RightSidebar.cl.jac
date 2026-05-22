"""Right sidebar for Little X: search, trending, and suggestions."""

import from "lucide-react" { Search, X }
sv import from ..server { UserView, TrendingTag }

def:pub RightSidebar(
    searchQuery: str,
    onSearchChange: any,
    onSearch: any,
    onClearSearch: any,
    trendingTags: list[TrendingTag],
    onTrendClick: any,
    toFollow: list[UserView],
    onFollow: any,
    onShowMore: any,
) -> JsxElement {
    searchChangeFn = onSearchChange;
    searchFn = onSearch;
    clearFn = onClearSearch;
    trendFn = onTrendClick;
    followFn = onFollow;
    showMoreFn = onShowMore;

    return
        <aside className="lx-sidebar-right">
            <div className="lx-sidebar-right-inner">
                <div className="lx-search-wrap">
                    <span className="lx-search-icon">
                        <Search size={16}/>
                    </span>
                    <input
                        className="lx-search-input"
                        placeholder="Search Little-X"
                        value={searchQuery}
                        onChange={lambda e: ChangeEvent { searchChangeFn.call(
                            None, e.target.value
                        ); }}
                        onKeyDown={lambda e: KeyboardEvent { if e.key == "Enter" {
                            searchFn.call(None, e.target.value);
                        }}}
                    />
                    {if searchQuery {
                        <button
                            className="lx-search-clear"
                            title="Clear search"
                            onClick={lambda { clearFn.call(None); }}
                        >
                            <X size={16}/>
                        </button>
                    }}
                    <button
                        className="lx-search-btn"
                        onClick={lambda { searchFn.call(None, searchQuery); }}
                    >
                        Search
                    </button>
                </div>
                {if len(trendingTags) > 0 {
                    <div className="lx-widget">
                        <div className="lx-widget-title">Trending</div>
                        {for t in trendingTags {
                            <div
                                className="lx-trend-item"
                                key={t.tag}
                                onClick={lambda { trendFn.call(None, t.tag); }}
                            >
                                <span className="lx-trend-tag">{t.tag}</span>
                                <span className="lx-trend-count">
                                    {str(t.count) + (
                                        " post" if t.count == 1 else " posts"
                                    )}
                                </span>
                            </div>
                        }}
                    </div>
                }}
                {if len(toFollow) > 0 {
                    <div className="lx-widget">
                        <div className="lx-widget-title">Who to follow</div>
                        {for u in toFollow[:5] {
                            <div className="lx-follow-item" key={u.id}>
                                <img
                                    className="lx-avatar-sm"
                                    src={"https://i.pravatar.cc/150?u=fake@" + u.username}
                                    alt={u.username}
                                />
                                <div className="lx-follow-item-info">
                                    <div className="lx-follow-item-name">
                                        {u.username.split("@")[0]
                                            if "@" in u.username
                                            else u.username}
                                    </div>
                                    <div className="lx-follow-item-handle">
                                        {"@" + (
                                            u.username.split("@")[0]
                                                if "@" in u.username
                                                else u.username
                                        )}
                                    </div>
                                </div>
                                <button
                                    className="lx-follow-btn"
                                    onClick={lambda { followFn.call(None, u.id); }}
                                >
                                    Follow
                                </button>
                            </div>
                        }}
                        {if len(toFollow) > 5 {
                            <div
                                className="lx-widget-show-more"
                                onClick={lambda { showMoreFn.call(None); }}
                            >
                                Show more
                            </div>
                        }}
                    </div>
                }}
                <div className="lx-about-widget">
                    <div className="lx-about-title">LITTLE-X</div>
                    <div className="lx-about-desc">
                        A decentralized social platform built with Jac. Share thoughts, follow people, join conversations.
                    </div>
                    <div className="lx-about-links">
                        <span className="lx-about-tag">{"#jacdev"}</span>
                        <span className="lx-about-tag">{"#jaseci"}</span>
                        <span className="lx-about-tag">{"#open-source"}</span>
                    </div>
                </div>
            </div>
        </aside>;
}
