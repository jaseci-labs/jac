"""Explore tab for Little X: discover and follow other users."""

sv import from ..server { UserView }

def:pub ExploreTab(
    allProfiles: list[UserView],
    followingIds: list[str],
    myProfileId: str,
    onFollow: any,
    onUnfollow: any,
) -> JsxElement {
    followFn = onFollow;
    unfollowFn = onUnfollow;

    return
        <div>
            {if not allProfiles {
                <div className="lx-loading">Loading users...</div>
            }for u in allProfiles {
                <div className="lx-explore-item" key={u.id}>
                    <img
                        className="lx-avatar"
                        src={"https://i.pravatar.cc/150?u=fake@" + u.username}
                        alt={u.username}
                    />
                    <div className="lx-explore-info">
                        <div className="lx-explore-name">
                            {u.username.split("@")[0]
                                if "@" in u.username
                                else u.username}
                        </div>
                        <div className="lx-explore-handle">
                            {"@" + (
                                u.username.split("@")[0]
                                    if "@" in u.username
                                    else u.username
                            )}
                        </div>
                        <div className="lx-explore-bio">{u.bio or "No bio yet"}</div>
                    </div>
                    {if u.id in followingIds {
                        <button
                            className="lx-unfollow-btn"
                            onClick={lambda { unfollowFn.call(None, u.id); }}
                        >
                            Following
                        </button>
                    } elif u.id != myProfileId {
                        <button
                            className="lx-follow-btn"
                            onClick={lambda { followFn.call(None, u.id); }}
                        >
                            Follow
                        </button>
                    } }
                </div>
            }}
        </div>;
}
