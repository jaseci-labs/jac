"""Home feed tab for Little X."""

sv import from ..server { TweetView }
import from .TweetCard { TweetCard }
import from .Composer { Composer }
import from .WelcomeBanner { WelcomeBanner }

def:pub FeedTab(
    showWelcome: bool,
    onDismissWelcome: Callable[[], None],
    profileAvatar: str,
    profileUsername: str,
    composerText: str,
    onComposerChange: Callable[[str], None],
    onPost: Callable[[], None],
    feedLoading: bool,
    tweets: list[TweetView],
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
                <div className="lx-loading">Loading feed...</div>
                skip;
            }if len(tweets) == 0 {
                <div className="lx-empty">
                    <div className="lx-empty-title">Nothing here yet</div>
                    <span>Follow people or post something!</span>
                </div>
                skip;
            }for tweet in tweets {
                <TweetCard
                    key={tweet.id}
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
