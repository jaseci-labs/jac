"""Profile tab for Little X."""

import from .ui.avatar { Avatar, AvatarImage, AvatarFallback }
import from .ui.button { Button }
import from .ui.textarea { Textarea }
import from .TweetCard { TweetCard }
sv import from ..social_graph { ProfileView }

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
    initial = displayUsername[0].upper() if displayUsername else "?";

    return
        <div>
            <div
                className="h-36 w-full bg-gradient-to-br from-primary/50 via-primary/20 to-background"
            />
            <div className="px-4 pb-3">
                <div className="-mt-12 flex items-end justify-between">
                    <Avatar className="size-24 border-4 border-background shadow-lg">
                        <AvatarImage src={profileAvatar} alt={profileUsername}/>
                        <AvatarFallback className="text-2xl">{initial}</AvatarFallback>
                    </Avatar>
                </div>
                <div
                    className="mt-3 font-display text-xl font-extrabold text-foreground"
                >
                    {displayUsername}
                </div>
                <div className="text-sm text-muted-foreground">
                    {"@" + displayUsername}
                </div>
                {if editingBio {
                    <div className="mt-3 flex flex-col gap-2">
                        <Textarea
                            rows={3}
                            placeholder="Write your bio..."
                            value={bioText}
                            onChange={lambda (e: ChangeEvent) { onBioChange(
                                e.target.value
                            ); }}
                        />
                        <div className="flex gap-2">
                            <Button
                                size="sm"
                                className="font-semibold"
                                onClick={lambda { onSaveBio(); }}
                            >
                                Save
                            </Button>
                            <Button
                                size="sm"
                                variant="outline"
                                onClick={lambda { onCancelEditBio(); }}
                            >
                                Cancel
                            </Button>
                        </div>
                    </div>
                } else {
                    <p className="mt-3 text-sm text-foreground/90">
                        {myProfile.bio if myProfile and myProfile.bio else "No bio yet"}
                    </p>
                } }
                <div className="mt-4 flex gap-5 text-sm">
                    <div className="flex items-center gap-1">
                        <span className="font-display font-bold text-foreground">
                            {str(followingCount)}
                        </span>
                        <span className="text-muted-foreground">Following</span>
                    </div>
                    <div className="flex items-center gap-1">
                        <span className="font-display font-bold text-foreground">
                            {str(followerCount)}
                        </span>
                        <span className="text-muted-foreground">
                            {("Follower" if followerCount == 1 else "Followers")}
                        </span>
                    </div>
                    <div className="flex items-center gap-1">
                        <span className="font-display font-bold text-foreground">
                            {str(postCount)}
                        </span>
                        <span className="text-muted-foreground">
                            {("Post" if postCount == 1 else "Posts")}
                        </span>
                    </div>
                </div>
            </div>
            <div className="border-t border-border">
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
            </div>
        </div>;
}
