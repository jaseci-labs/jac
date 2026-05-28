"""Profile tab for Little X."""

sv import from ..server { ProfileView }
import from .TweetCard { TweetCard }

def:pub ProfileTab(
    myProfile: ProfileView | None,
    displayUsername: str,
    profileAvatar: str,
    profileUsername: str,
    editingBio: bool,
    bioText: str,
    onBioChange: Callable[[str], None],
    onSaveBio: Callable[[], None],
    onCancelEditBio: Callable[[], None],
    onLike: Callable[[str], None],
    onComment: Callable[[str, str], None],
    onDelete: Callable[[str], None],
    onRepost: Callable[[str, str, str], None],
) -> JsxElement {
    followingCount = len(myProfile.following)
        if myProfile and myProfile.following
        else 0;
    followerCount = len(myProfile.followers)
        if myProfile and myProfile.followers
        else 0;
    postCount = len(myProfile.tweets) if myProfile and myProfile.tweets else 0;
    myTweets = myProfile.tweets if myProfile and myProfile.tweets else [];

    return
        <div>
            <div className="lx-profile-banner"/>
            <div className="lx-profile-info">
                <div className="lx-profile-avatar-wrap">
                    <img
                        className="lx-avatar-lg"
                        src={profileAvatar}
                        alt={profileUsername}
                    />
                </div>
                <div className="lx-profile-display-name">{displayUsername}</div>
                <div className="lx-profile-handle">{"@" + displayUsername}</div>
                {if editingBio {
                    <div className="lx-bio-edit-wrap">
                        <textarea
                            className="lx-bio-input"
                            rows={3}
                            placeholder="Write your bio..."
                            value={bioText}
                            onChange={lambda e: ChangeEvent { onBioChange(
                                e.target.value
                            ); }}
                        />
                        <div style={{"display": "flex", "gap": "0.5rem"}}>
                            <button
                                className="lx-bio-save-btn"
                                onClick={lambda { onSaveBio(); }}
                            >
                                Save
                            </button>
                            <button
                                className="lx-edit-profile-btn"
                                onClick={lambda { onCancelEditBio(); }}
                            >
                                Cancel
                            </button>
                        </div>
                    </div>
                } else {
                    <div className="lx-profile-bio-text">
                        {myProfile.bio if myProfile and myProfile.bio else "No bio yet"}
                    </div>
                } }
                <div className="lx-profile-stats">
                    <div className="lx-profile-stat">
                        <strong>{str(followingCount)}</strong>
                        Following
                    </div>
                    <div className="lx-profile-stat">
                        <strong>{str(followerCount)}</strong>
                        {("Follower" if followerCount == 1 else "Followers")}
                    </div>
                    <div className="lx-profile-stat">
                        <strong>{str(postCount)}</strong>
                        {("Post" if postCount == 1 else "Posts")}
                    </div>
                </div>
            </div>
            {for tweet in myTweets {
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
