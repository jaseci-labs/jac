"""Little X - Frontend declarations.

The `app` component owns shared state and server handlers, then delegates
rendering to focused components in `components/`. See `frontend.impl.jac`
for handler implementations.
"""

import from "@jac/runtime" { jacSignup, jacLogin, jacLogout, jacIsLoggedIn }
sv import from .social_graph {
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
sv import from .social_graph {
    Profile,
    Tweet,
    TrendingTag,
    ProfileBundle,
    ChannelBundle
}
import from "lucide-react" { Feather, Sun, Moon, Pencil }
import from .components.ui.button { Button }
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
        darkMode: bool = True,
        myProfile: ProfileBundle | None = None,
        tweets: list[Tweet] = [],
        feedLoading: bool = True,
        composerText: str = "",
        searchQuery: str = "",
        allProfiles: list[Profile] = [],
        editingBio: bool = False,
        bioText: str = "",
        trendingTags: list[TrendingTag] = [],
        notifCount: int = 0,
        showWelcome: bool = False,
        channels: list[ChannelBundle] = [],
        channelsLoading: bool = False,
        selectedChannel: ChannelBundle | None = None,
        channelPosts: list[Tweet] = [];

    can with entry {
        isLoggedIn = jacIsLoggedIn();
        checkingAuth = False;
    }

    can with [darkMode] entry {
        if darkMode {
            document.documentElement.classList.add("dark");
        } else {
            document.documentElement.classList.remove("dark");
        }
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

    get_tab_name = lambda (t: str) { return (
        "Home"
            if t == "feed"
            else (
                "Explore"
                    if t == "explore"
                    else ("Channels" if t == "channels" else "Profile")
            )
    ); };

    if checkingAuth {
        return
            <div
                className="flex min-h-screen items-center justify-center bg-background"
            >
                <div
                    className="size-8 animate-spin rounded-full border-2 border-primary border-t-transparent"
                />
            </div>;
    }

    if not isLoggedIn {
        return
            <AuthForm
                {isSignup}
                username={authUsername}
                password={authPassword}
                error={authError}
                loading={authLoading}
                onUsernameChange={lambda (e: ChangeEvent) { authUsername = e.target.value; }}
                onPasswordChange={lambda (e: ChangeEvent) { authPassword = e.target.value; }}
                onSubmit={lambda (e: FormEvent) {
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

    profileUsername = myProfile.profile.username if myProfile else "";
    displayUsername = profileUsername.split("@")[0]
        if "@" in profileUsername
        else profileUsername;
    profileAvatar = "https://i.pravatar.cc/150?u=fake@" + profileUsername;
    myProfileId = jid(myProfile.profile) if myProfile else "";
    followingIds = [
        jid(f)
        for f in (myProfile.following if myProfile and myProfile.following else [])
    ];
    toFollow = [
        u
        for u in allProfiles
        if jid(u) not in followingIds and jid(u) != myProfileId
    ];

    return
        <div
            className="mx-auto flex min-h-screen w-full max-w-7xl bg-background text-foreground"
        >
            <Sidebar
                {activeTab}
                {displayUsername}
                {profileUsername}
                {profileAvatar}
                {notifCount}
                onNavigate={navigate}
                onLogout={handleLogout}
            />
            <main
                className="min-h-screen min-w-0 flex-1 border-x border-border pb-20 md:pb-0"
            >
                <header
                    className="sticky top-0 z-30 flex items-center justify-between gap-2 border-b border-border bg-background/80 px-4 py-3 backdrop-blur-lg"
                >
                    <span className="font-display text-xl font-extrabold">
                        {get_tab_name(activeTab)}
                    </span>
                    <div className="flex items-center gap-1">
                        {if activeTab == "profile" {
                            <Button
                                variant="outline"
                                size="sm"
                                className="rounded-full"
                                onClick={lambda {
                                    editingBio = not editingBio;
                                    bioText = (
                                        myProfile.profile.bio
                                            if myProfile and myProfile.profile.bio
                                            else ""
                                    );
                                }}
                            >
                                <Pencil size={14}/>
                                {"Cancel" if editingBio else "Edit profile"}
                            </Button>
                        }}
                        <Button
                            variant="ghost"
                            size="icon"
                            className="rounded-full text-muted-foreground"
                            title="Toggle theme"
                            onClick={lambda { darkMode = not darkMode; }}
                        >
                            {if darkMode {
                                <Sun size={18}/>
                            } else {
                                <Moon size={18}/>
                            } }
                        </Button>
                    </div>
                </header>
                {if activeTab == "feed" {
                    <FeedTab
                        {showWelcome}
                        onDismissWelcome={handleDismissWelcome}
                        {profileAvatar}
                        {profileUsername}
                        {composerText}
                        onComposerChange={lambda (v: str) { composerText = v; }}
                        onPost={postTweet}
                        {feedLoading}
                        {tweets}
                        onLike={handleLike}
                        onComment={handleComment}
                        onDelete={handleDelete}
                        onRepost={handleRepost}
                    />
                } elif activeTab == "explore" {
                    <ExploreTab
                        {allProfiles}
                        {followingIds}
                        {myProfileId}
                        onFollow={handleFollow}
                        onUnfollow={handleUnfollow}
                    />
                } elif activeTab == "channels" {
                    <ChannelsTab
                        {channels}
                        {channelsLoading}
                        {selectedChannel}
                        {channelPosts}
                        {profileAvatar}
                        {profileUsername}
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
                } elif activeTab == "profile" {
                    <ProfileTab
                        {myProfile}
                        {displayUsername}
                        {profileAvatar}
                        {profileUsername}
                        {editingBio}
                        {bioText}
                        onBioChange={lambda (v: str) { bioText = v; }}
                        onSaveBio={handleSaveBio}
                        onCancelEditBio={lambda { editingBio = False; }}
                        onLike={handleLike}
                        onComment={handleComment}
                        onDelete={handleDelete}
                        onRepost={handleRepost}
                    />
                }   }
            </main>
            <RightSidebar
                {searchQuery}
                onSearchChange={lambda (v: str) { searchQuery = v; }}
                onSearch={handleSearch}
                onClearSearch={lambda {
                    searchQuery = "";
                    handleSearch("");
                }}
                {trendingTags}
                onTrendClick={handleTrendClick}
                {toFollow}
                onFollow={handleFollow}
                onShowMore={lambda { navigate("explore"); }}
            />
            <MobileNav {activeTab} {notifCount} onNavigate={navigate}/>
            <Button
                className="fixed bottom-20 right-4 z-40 size-14 rounded-full shadow-lg shadow-primary/30 md:hidden"
                onClick={lambda { navigate("feed"); }}
            >
                <Feather size={22}/>
            </Button>
        </div>;
}
