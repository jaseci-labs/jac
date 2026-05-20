"""Little X - Frontend declarations.

The `app` component owns shared state and server handlers, then delegates
rendering to focused components in `components/`. See `frontend.impl.jac`
for handler implementations.
"""

import from "@jac/runtime" { jacSignup, jacLogin, jacLogout, jacIsLoggedIn }
sv import from .server {
    setup_profile,
    get_profile,
    get_all_profiles,
    follow_user,
    unfollow_user,
    create_tweet,
    delete_tweet,
    like_tweet,
    add_comment,
    load_feed,
    get_trending,
    create_channel,
    join_channel,
    leave_channel,
    get_channels,
    get_channel_detail,
    create_channel_tweet
}
sv import from .server { UserView, TweetView, ChannelView, TrendingTag, ProfileView }
import from "lucide-react" { Feather }
import from .components.AuthForm { AuthForm }
import from .components.Sidebar { Sidebar }
import from .components.RightSidebar { RightSidebar }
import from .components.MobileNav { MobileNav }
import from .components.FeedTab { FeedTab }
import from .components.ExploreTab { ExploreTab }
import from .components.ChannelsTab { ChannelsTab }
import from .components.ProfileTab { ProfileTab }
import "./global.css";

def:pub app -> JsxElement {
    has isLoggedIn: bool = False,
        checkingAuth: bool = True,
        isSignup: bool = False,
        authUsername: str = "",
        authPassword: str = "",
        authError: str = "",
        authLoading: bool = False,
        activeTab: str = "feed",
        myProfile: ProfileView | None = None,
        tweets: list[TweetView] = [],
        feedLoading: bool = True,
        composerText: str = "",
        searchQuery: str = "",
        allProfiles: list[UserView] = [],
        editingBio: bool = False,
        bioText: str = "",
        trendingTags: list[TrendingTag] = [],
        notifCount: int = 0,
        showWelcome: bool = False,
        channels: list[ChannelView] = [],
        channelsLoading: bool = False,
        selectedChannel: ChannelView | None = None,
        channelPosts: list[TweetView] = [];

    can with entry {
        isLoggedIn = jacIsLoggedIn();
        checkingAuth = False;
    }

    can with [isLoggedIn] entry {
        if isLoggedIn {
            showWelcome = not localStorage.getItem("lx_welcomed");
            loadData();
        }
    }

    async def loadData -> None;
    async def handleLogin -> None;
    async def handleSignup -> None;
    def handleLogout -> None;
    async def postTweet -> None;
    async def handleLike(tweetId: str) -> None;
    async def handleComment(tweetId: str, content: str) -> None;
    async def handleDelete(tweetId: str) -> None;
    async def handleFollow(profileId: str) -> None;
    async def handleUnfollow(profileId: str) -> None;
    async def handleSaveBio -> None;
    async def handleSearch(query: str) -> None;
    def handleRepost(tweetId: str, content: str, author: str) -> None;
    def handleDismissWelcome -> None;
    def handleTrendClick(tag: str) -> None;
    def navigate(tab: str) -> None;
    async def loadChannels -> None;
    async def handleCreateChannel(name: str, description: str) -> None;
    async def handleJoinChannel(channelId: str) -> None;
    async def handleLeaveChannel(channelId: str) -> None;
    async def handleSelectChannel(channelId: str) -> None;
    async def handleChannelPost(text: str) -> None;
    def handleBackToChannels -> None;

    if checkingAuth {
        return
            <div className="lx-loading">Loading...</div>;
    }

    if not isLoggedIn {
        return
            <AuthForm
                isSignup={isSignup}
                username={authUsername}
                password={authPassword}
                error={authError}
                loading={authLoading}
                onUsernameChange={lambda e: ChangeEvent { authUsername = e.target.value; }}
                onPasswordChange={lambda e: ChangeEvent { authPassword = e.target.value; }}
                onSubmit={lambda e: FormEvent {
                    e.preventDefault();
                    if isSignup {
                        handleSignup();
                    } else {
                        handleLogin();
                    }
                }}
                onToggleMode={lambda {
                    isSignup = not isSignup;
                    authError = "";
                }}
            />;
    }

    profileUsername = myProfile.username if myProfile else "";
    displayUsername = profileUsername.split("@")[0]
        if "@" in profileUsername
        else profileUsername;
    profileAvatar = "https://i.pravatar.cc/150?u=fake@" + profileUsername;
    myProfileId = myProfile.id if myProfile else "";
    followingIds = [f.id for f in myProfile.following]
        if myProfile and myProfile.following
        else [];
    toFollow = [
        u
        for u in allProfiles
        if u.id not in followingIds and u.id != myProfileId
    ];

    return
        <div className="lx-root">
            <Sidebar
                activeTab={activeTab}
                displayUsername={displayUsername}
                profileUsername={profileUsername}
                profileAvatar={profileAvatar}
                notifCount={notifCount}
                onNavigate={navigate}
                onLogout={handleLogout}
            />
            <main className="lx-main">
                <div className="lx-feed-header">
                    <span className="lx-feed-title">
                        {(
                            "Home"
                                if activeTab == "feed"
                                else (
                                    "Explore"
                                        if activeTab == "explore"
                                        else (
                                            "Channels"
                                                if activeTab == "channels"
                                                else "Profile"
                                        )
                                )
                        )}
                    </span>
                    {(
                        <button
                            className="lx-edit-profile-btn"
                            onClick={lambda {
                                editingBio = not editingBio;
                                bioText = (
                                    myProfile.bio if myProfile and myProfile.bio else ""
                                );
                            }}
                        >
                            {"Cancel" if editingBio else "Edit profile"}
                        </button>
                    )
                        if activeTab == "profile"
                        else None}
                </div>
                {(
                    <FeedTab
                        showWelcome={showWelcome}
                        onDismissWelcome={handleDismissWelcome}
                        profileAvatar={profileAvatar}
                        profileUsername={profileUsername}
                        composerText={composerText}
                        onComposerChange={lambda v: str { composerText = v; }}
                        onPost={postTweet}
                        feedLoading={feedLoading}
                        tweets={tweets}
                        onLike={handleLike}
                        onComment={handleComment}
                        onDelete={handleDelete}
                        onRepost={handleRepost}
                    />
                )
                    if activeTab == "feed"
                    else None}
                {(
                    <ExploreTab
                        allProfiles={allProfiles}
                        followingIds={followingIds}
                        myProfileId={myProfileId}
                        onFollow={handleFollow}
                        onUnfollow={handleUnfollow}
                    />
                )
                    if activeTab == "explore"
                    else None}
                {(
                    <ChannelsTab
                        channels={channels}
                        channelsLoading={channelsLoading}
                        selectedChannel={selectedChannel}
                        channelPosts={channelPosts}
                        profileAvatar={profileAvatar}
                        profileUsername={profileUsername}
                        onCreateChannel={handleCreateChannel}
                        onJoinChannel={handleJoinChannel}
                        onLeaveChannel={handleLeaveChannel}
                        onSelectChannel={handleSelectChannel}
                        onChannelPost={handleChannelPost}
                        onBackToChannels={handleBackToChannels}
                        onLike={handleLike}
                        onComment={handleComment}
                        onDelete={handleDelete}
                        onRepost={handleRepost}
                    />
                )
                    if activeTab == "channels"
                    else None}
                {(
                    <ProfileTab
                        myProfile={myProfile}
                        displayUsername={displayUsername}
                        profileAvatar={profileAvatar}
                        profileUsername={profileUsername}
                        editingBio={editingBio}
                        bioText={bioText}
                        onBioChange={lambda v: str { bioText = v; }}
                        onSaveBio={handleSaveBio}
                        onCancelEditBio={lambda { editingBio = False; }}
                        onLike={handleLike}
                        onComment={handleComment}
                        onDelete={handleDelete}
                        onRepost={handleRepost}
                    />
                )
                    if activeTab == "profile"
                    else None}
            </main>
            <RightSidebar
                searchQuery={searchQuery}
                onSearchChange={lambda v: str { searchQuery = v; }}
                onSearch={handleSearch}
                onClearSearch={lambda {
                    searchQuery = "";
                    handleSearch("");
                }}
                trendingTags={trendingTags}
                onTrendClick={handleTrendClick}
                toFollow={toFollow}
                onFollow={handleFollow}
                onShowMore={lambda { navigate("explore"); }}
            />
            <MobileNav
                activeTab={activeTab}
                notifCount={notifCount}
                onNavigate={navigate}
            />
            <button className="lx-mobile-fab" onClick={lambda { navigate("feed"); }}>
                <Feather size={22}/>
            </button>
        </div>;
}
