"""Home feed tab for Little X."""

import from "lucide-react" { Inbox }
import from .ui.skeleton { Skeleton }
import from .ui.empty { Empty, EmptyHeader, EmptyMedia, EmptyTitle, EmptyDescription }
import from .TweetCard { TweetCard }
import from .Composer { Composer }
import from .WelcomeBanner { WelcomeBanner }
sv import from ..social_graph { Tweet }

def:pub FeedTab(
    showWelcome: bool,
    onDismissWelcome: Callable[[], None],
    profileAvatar: str,
    profileUsername: str,
    composerText: str,
    onComposerChange: Callable[[str], None],
    onPost: Callable[[], None],
    feedLoading: bool,
    tweets: list[Tweet],
    onLike: Callable[[str], None],
    onComment: Callable[[str, str], None],
    onDelete: Callable[[str], None],
    onRepost: Callable[[str, str, str], None],
) -> JsxElement {
    return
        <div>
            {if showWelcome {
                <WelcomeBanner onDismiss={onDismissWelcome}/>
            }}
            <Composer
                avatar={profileAvatar}
                avatarAlt={profileUsername}
                placeholder="What's happening?"
                value={composerText}
                onChange={onComposerChange}
                {onPost}
                rows={3}
                buttonLabel="Post"
                showCharRing={True}
            />
            {if feedLoading {
                <div className="flex flex-col gap-4 p-4">
                    {[
                        <div className="flex gap-3" key={i}>
                            <Skeleton className="size-10 rounded-full"/>
                            <div className="flex-1 space-y-2">
                                <Skeleton className="h-3 w-32"/>
                                <Skeleton className="h-3 w-full"/>
                                <Skeleton className="h-3 w-2/3"/>
                            </div>
                        </div> for i in range(4)
                    ]}
                </div>
                skip;
            }if len(tweets) == 0 {
                <Empty className="py-16">
                    <EmptyHeader>
                        <EmptyMedia variant="icon">
                            <Inbox/>
                        </EmptyMedia>
                        <EmptyTitle>Nothing here yet</EmptyTitle>
                        <EmptyDescription>
                            Follow people or post something to fill your feed.
                        </EmptyDescription>
                    </EmptyHeader>
                </Empty>
                skip;
            }for tweet in tweets {
                <TweetCard
                    key={jid(tweet)}
                    {tweet}
                    myUsername={profileUsername}
                    {onLike}
                    {onComment}
                    {onDelete}
                    {onRepost}
                />
            }}
        </div>;
}
