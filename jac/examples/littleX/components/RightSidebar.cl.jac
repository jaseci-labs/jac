"""Right sidebar for Little X: search, trending, and suggestions."""

import from "lucide-react" { Search, X, TrendingUp }
import from .ui.input { Input }
import from .ui.button { Button }
import from .ui.card { Card, CardHeader, CardTitle, CardContent }
import from .ui.avatar { Avatar, AvatarImage, AvatarFallback }
import from .ui.badge { Badge }
import from .ui.hover_card { HoverCard, HoverCardTrigger, HoverCardContent }
sv import from ..social_graph { Profile, TrendingTag }

def:pub RightSidebar(
    searchQuery: str,
    onSearchChange: Callable[[str], None],
    onSearch: Callable[[str], None],
    onClearSearch: Callable[[], None],
    trendingTags: list[TrendingTag],
    onTrendClick: Callable[[str], None],
    toFollow: list[Profile],
    onFollow: Callable[[str], None],
    onShowMore: Callable[[], None],
) -> JsxElement {
    return
        <aside
            className="sticky top-0 hidden h-screen w-80 shrink-0 flex-col gap-4 overflow-y-auto border-l border-border px-4 py-4 lg:flex"
        >
            <div className="relative">
                <Search
                    size={16}
                    className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground"
                />
                <Input
                    className="rounded-full bg-muted pl-9 pr-9"
                    placeholder="Search Little-X"
                    value={searchQuery}
                    onChange={lambda (e: ChangeEvent) { onSearchChange(
                        e.target.value
                    ); }}
                    onKeyDown={lambda (e: KeyboardEvent) { if e.key == "Enter" {
                        onSearch(searchQuery);
                    }}}
                />
                {if searchQuery {
                    <button
                        className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
                        title="Clear search"
                        onClick={lambda { onClearSearch(); }}
                    >
                        <X size={16}/>
                    </button>
                }}
            </div>
            {if len(trendingTags) > 0 {
                <Card className="gap-0 overflow-hidden py-0">
                    <CardHeader className="border-b border-border py-3">
                        <CardTitle
                            className="flex items-center gap-2 text-base font-display"
                        >
                            <TrendingUp size={16} className="text-primary"/>
                            Trending
                        </CardTitle>
                    </CardHeader>
                    <CardContent className="px-0 py-1">
                        {for t in trendingTags {
                            <button
                                className="flex w-full flex-col items-start px-4 py-2 text-left transition-colors hover:bg-muted/50"
                                key={t.tag}
                                onClick={lambda { onTrendClick(t.tag); }}
                            >
                                <span className="font-semibold text-primary">
                                    {t.tag}
                                </span>
                                <span className="text-xs text-muted-foreground">
                                    {str(t.count) + (
                                        " post" if t.count == 1 else " posts"
                                    )}
                                </span>
                            </button>
                        }}
                    </CardContent>
                </Card>
            }}
            {if len(toFollow) > 0 {
                <Card className="gap-0 overflow-hidden py-0">
                    <CardHeader className="border-b border-border py-3">
                        <CardTitle className="text-base font-display">
                            Who to follow
                        </CardTitle>
                    </CardHeader>
                    <CardContent className="px-0 py-1">
                        {for u in toFollow[:5] {
                            <div
                                className="flex items-center gap-2 px-4 py-2 transition-colors hover:bg-muted/50"
                                key={jid(u)}
                            >
                                <Avatar className="size-9 shrink-0">
                                    <AvatarImage
                                        src={"https://i.pravatar.cc/150?u=fake@" + u.username}
                                        alt={u.username}
                                    />
                                    <AvatarFallback>
                                        {(
                                            u.username.split("@")[0]
                                                if "@" in u.username
                                                else u.username
                                        )[0].upper()}
                                    </AvatarFallback>
                                </Avatar>
                                <div className="min-w-0 flex-1">
                                    <HoverCard>
                                        <HoverCardTrigger asChild={True}>
                                            <span
                                                className="block cursor-pointer truncate text-sm font-semibold text-foreground hover:underline"
                                            >
                                                {u.username.split("@")[0]
                                                    if "@" in u.username
                                                    else u.username}
                                            </span>
                                        </HoverCardTrigger>
                                        <HoverCardContent className="w-64">
                                            <div className="flex items-center gap-3">
                                                <Avatar className="size-11">
                                                    <AvatarImage
                                                        src={"https://i.pravatar.cc/150?u=fake@" + u.username}
                                                        alt={u.username}
                                                    />
                                                    <AvatarFallback>
                                                        {(
                                                            u.username.split("@")[0]
                                                                if "@" in u.username
                                                                else u.username
                                                        )[0].upper()}
                                                    </AvatarFallback>
                                                </Avatar>
                                                <div className="min-w-0">
                                                    <div
                                                        className="truncate font-semibold text-foreground"
                                                    >
                                                        {u.username.split("@")[0]
                                                            if "@" in u.username
                                                            else u.username}
                                                    </div>
                                                    <div
                                                        className="truncate text-xs text-muted-foreground"
                                                    >
                                                        {"@" + (
                                                            u.username.split("@")[0]
                                                                if "@" in u.username
                                                                else u.username
                                                        )}
                                                    </div>
                                                </div>
                                            </div>
                                            <p
                                                className="mt-2 line-clamp-3 text-sm text-muted-foreground"
                                            >
                                                {u.bio or "No bio yet"}
                                            </p>
                                        </HoverCardContent>
                                    </HoverCard>
                                    <div
                                        className="truncate text-xs text-muted-foreground"
                                    >
                                        {"@" + (
                                            u.username.split("@")[0]
                                                if "@" in u.username
                                                else u.username
                                        )}
                                    </div>
                                </div>
                                <Button
                                    size="sm"
                                    className="shrink-0 rounded-full font-semibold"
                                    onClick={lambda { onFollow(jid(u)); }}
                                >
                                    Follow
                                </Button>
                            </div>
                        }}
                        {if len(toFollow) > 5 {
                            <button
                                className="w-full px-4 py-2 text-left text-sm text-primary hover:bg-muted/50"
                                onClick={lambda { onShowMore(); }}
                            >
                                Show more
                            </button>
                        }}
                    </CardContent>
                </Card>
            }}
            <Card className="bg-muted/30">
                <CardHeader>
                    <CardTitle className="font-display text-base text-primary">
                        LITTLE-X
                    </CardTitle>
                </CardHeader>
                <CardContent className="-mt-3">
                    <p className="text-sm text-muted-foreground">
                        A decentralized social platform built with Jac. Share thoughts, follow people, join conversations.
                    </p>
                    <div className="mt-3 flex flex-wrap gap-1.5">
                        <Badge variant="secondary">#jacdev</Badge>
                        <Badge variant="secondary">#jaseci</Badge>
                        <Badge variant="secondary">#open-source</Badge>
                    </div>
                </CardContent>
            </Card>
        </aside>;
}
