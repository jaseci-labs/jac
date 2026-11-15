impl ExploreTab(
    allProfiles: list[Profile],
    followingIds: list[str],
    myProfileId: str,
    avatars: dict[str, str],
    onFollow: Callable[[str], None],
    onUnfollow: Callable[[str], None],
    onViewProfile: Callable[[str], None],
) -> JsxElement {
    <div>
        {if not allProfiles {
            <div className="flex flex-col gap-4 p-4">
                {[
                    <div className="flex items-center gap-3" key={i}>
                        <Skeleton className="size-11 rounded-full"/>
                        <div className="flex-1 space-y-2">
                            <Skeleton className="h-3 w-28"/>
                            <Skeleton className="h-3 w-40"/>
                        </div>
                        <Skeleton className="h-9 w-20 rounded-full"/>
                    </div> for i in range(5)
                ]}
            </div>
        }for u in allProfiles {
            <div
                className="lx-fade-up flex items-center gap-3 border-b border-border px-4 py-3 transition-colors hover:bg-muted/30"
                key={jid(u)}
            >
                <button
                    type="button"
                    className="flex min-w-0 flex-1 items-center gap-3 text-left"
                    onClick={lambda { onViewProfile(u.username); }}
                >
                    <Avatar className="size-11 shrink-0">
                        <AvatarImage
                            src={avatar_of(avatars, u.username)}
                            alt={handle_of(u.username)}
                        />
                        <AvatarFallback>
                            {initial_of(name_of(u.display_name, u.username))}
                        </AvatarFallback>
                    </Avatar>
                    <div className="min-w-0 flex-1">
                        <div
                            className="font-display font-bold text-foreground truncate"
                        >
                            {name_of(u.display_name, u.username)}
                        </div>
                        <div className="text-sm text-muted-foreground truncate">
                            {"@" + handle_of(u.username)}
                        </div>
                        <div className="mt-0.5 line-clamp-2 text-sm text-foreground/80">
                            {u.bio or "No bio yet"}
                        </div>
                    </div>
                </button>
                {if jid(u) in followingIds {
                    <Button
                        variant="outline"
                        size="sm"
                        className="group shrink-0 rounded-full hover:border-destructive/40 hover:bg-destructive/10 hover:text-destructive"
                        onClick={lambda { onUnfollow(jid(u)); }}
                    >
                        <span className="group-hover:hidden">Following</span>
                        <span className="hidden group-hover:inline">Unfollow</span>
                    </Button>
                } elif jid(u) != myProfileId {
                    <Button
                        size="sm"
                        className="shrink-0 rounded-full font-semibold"
                        onClick={lambda { onFollow(jid(u)); }}
                    >
                        Follow
                    </Button>
                } }
            </div>
        }}
        {if allProfiles and len(allProfiles) == 0 {
            <Empty className="py-16">
                <EmptyHeader>
                    <EmptyMedia variant="icon">
                        <Users/>
                    </EmptyMedia>
                    <EmptyTitle>No one to show</EmptyTitle>
                    <EmptyDescription>
                        Check back later to discover more people.
                    </EmptyDescription>
                </EmptyHeader>
            </Empty>
        }}
    </div>
}
