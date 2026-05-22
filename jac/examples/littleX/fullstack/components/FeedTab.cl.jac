"""Home feed tab for Little X."""

sv import from ..server { TweetView }
import from .TweetCard { TweetCard }
import from .Composer { Composer }
import from .WelcomeBanner { WelcomeBanner }

def:pub FeedTab(
    showWelcome: bool,
    onDismissWelcome: any,
    profileAvatar: str,
    profileUsername: str,
    composerText: str,
    onComposerChange: any,
    onPost: any,
    feedLoading: bool,
    tweets: list[TweetView],
    onLike: any,
    onComment: any,
    onDelete: any,
    onRepost: any,
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
                onPost={onPost}
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
                    tweet={tweet}
                    myUsername={profileUsername}
                    onLike={onLike}
                    onComment={onComment}
                    onDelete={onDelete}
                    onRepost={onRepost}
                />
            }}
        </div>;
}
