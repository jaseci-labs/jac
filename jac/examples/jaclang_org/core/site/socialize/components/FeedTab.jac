import from "lucide-react" { Inbox }
import from core.site.ui.skeleton { Skeleton }
import from core.site.ui.empty {
    Empty,
    EmptyHeader,
    EmptyMedia,
    EmptyTitle,
    EmptyDescription
}
import from .TweetCard { TweetCard }
import from .Composer { Composer }
import from .WelcomeBanner { WelcomeBanner }
import from core.social_graph { Tweet }

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
    avatars: dict[str, str],
    onViewProfile: Callable[[str], None],
    onLike: Callable[[str], None],
    onComment: Callable[[str, str], None],
    onDelete: Callable[[str], None],
    onRepost: Callable[[str, str, str], None],
) -> JsxElement {
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
                {avatars}
                {onViewProfile}
                {onLike}
                {onComment}
                {onDelete}
                {onRepost}
            />
        }}
    </div>
}
