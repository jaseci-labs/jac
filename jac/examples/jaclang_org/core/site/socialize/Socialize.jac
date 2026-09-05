import from "@jac/runtime" { jacSignup, jacLogin, jacLogout, jacIsLoggedIn }
import from core.social_graph {
    setup_profile,
    update_profile,
    get_profile,
    get_user_profile,
    get_all_profiles,
    get_avatars,
    set_avatar,
    clear_avatar,
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
    create_channel_tweet,
    add_project,
    remove_project,
    rescore_project,
    get_all_projects
}
import from core.social_graph {
    Profile,
    Tweet,
    Project,
    TrendingTag,
    ProfileBundle,
    ChannelBundle
}
import from .identity { name_of, avatar_of, project_error_message }
import from "lucide-react" { Feather, ArrowLeft }
import from core.site.ui.button { Button }
import from .components.AuthForm { AuthForm }
import from .components.Sidebar { Sidebar }
import from .components.RightSidebar { RightSidebar }
import from .components.MobileNav { MobileNav }
import from .components.FeedTab { FeedTab }
import from .components.ExploreTab { ExploreTab }
import from .components.ChannelsTab { ChannelsTab }
import from .components.ProfileHeader { ProfileHeader }
import from .components.ProfileEditor { ProfileEditor }
import from .components.ProjectsPanel { ProjectsPanel }
import from .components.TweetCard { TweetCard }

glob AVATAR_SIDE: int = 256;

async def shrink_avatar(file: any) -> str {
    win: any = window;
    bmp: any = await win.createImageBitmap(file);
    side = bmp.width if bmp.width < bmp.height else bmp.height;
    canvas: any = document.createElement("canvas");
    canvas.width = AVATAR_SIDE;
    canvas.height = AVATAR_SIDE;
    ctx: any = canvas.getContext("2d");
    ctx.drawImage(
        bmp,
        (bmp.width - side) / 2,
        (bmp.height - side) / 2,
        side,
        side,
        0,
        0,
        AVATAR_SIDE,
        AVATAR_SIDE
    );
    bmp.close();
    return canvas.toDataURL("image/jpeg", 0.86);
}

def:pub Socialize -> JsxElement {
    has isLoggedIn: bool = False,
        checkingAuth: bool = True,
        isSignup: bool = False,
        authUsername: str = "",
        authPassword: str = "",
        authError: str = "",
        authLoading: bool = False,
        activeTab: str = "feed",
        myProfile: ProfileBundle | None = None,
        tweets: list[Tweet] = [],
        feedLoading: bool = True,
        composerText: str = "",
        searchQuery: str = "",
        allProfiles: list[Profile] = [],
        avatars: dict[str, str] = {},
        avatarSeen: dict[str, str] = {},
        editingProfile: bool = False,
        profileSaving: bool = False,
        profileError: str = "",
        avatarBusy: bool = False,
        viewedProfile: ProfileBundle | None = None,
        viewedLoading: bool = False,
        exploreMode: str = "people",
        allProjects: list[Project] = [],
        projectsLoading: bool = False,
        projectBusy: bool = False,
        projectError: str = "",
        projectNotice: str = "",
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

    can with [isLoggedIn] entry {
        if isLoggedIn {
            showWelcome = not localStorage.getItem("lx_welcomed");
            loadData();
        }
    }

    async def loadData -> None;
    async def refreshAvatars -> None;
    async def handleLogin -> None;
    async def handleSignup -> None;
    def handleLogout -> None;
    async def postTweet -> None;
    async def handleLike(tweetId: str) -> None;
    async def handleComment(tweetId: str, content: str) -> None;
    async def handleDelete(tweetId: str) -> None;
    async def handleFollow(profileId: str) -> None;
    async def handleUnfollow(profileId: str) -> None;
    async def handleSaveProfile(fields: dict[str, str]) -> None;
    async def handleAvatarFile(file: any) -> None;
    async def handleClearAvatar -> None;
    async def handleViewProfile(username: str) -> None;
    async def loadProjects -> None;
    async def handleAddProject(url: str) -> None;
    async def handleRemoveProject(projectId: str) -> None;
    async def handleRescoreProject(projectId: str) -> None;
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
            <div
                className="flex min-h-[calc(100vh-4rem)] items-center justify-center bg-background"
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
    displayUsername = name_of(myProfile.profile) if myProfile else "";
    profileAvatar = avatar_of(avatars, profileUsername);
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
    viewedName = name_of(viewedProfile.profile) if viewedProfile else "Profile";
    tab_title = (
        "Home"
            if activeTab == "feed"
            else (
                "Explore"
                    if activeTab == "explore"
                    else (
                        "Channels"
                            if activeTab == "channels"
                            else ("Profile" if activeTab == "profile" else viewedName)
                    )
            )
    );

    <div
        className="mx-auto flex min-h-[calc(100vh-4rem)] w-full max-w-7xl bg-background text-foreground"
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
            className="min-h-[calc(100vh-4rem)] min-w-0 flex-1 border-x border-border pb-20 md:pb-0"
        >
            <header
                className="sticky top-16 z-30 flex items-center gap-2 border-b border-border bg-background/80 px-4 py-3 backdrop-blur-lg"
            >
                {if activeTab == "user" {
                    <Button
                        variant="ghost"
                        size="icon"
                        className="size-8 rounded-full"
                        id="lx-back"
                        onClick={lambda { navigate("explore"); }}
                    >
                        <ArrowLeft size={18}/>
                    </Button>
                }}
                <span className="font-display text-xl font-extrabold" id="lx-tab-title">
                    {tab_title}
                </span>
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
                    {avatars}
                    onViewProfile={handleViewProfile}
                    onLike={handleLike}
                    onComment={handleComment}
                    onDelete={handleDelete}
                    onRepost={handleRepost}
                />
            } elif activeTab == "explore" {
                <ExploreTab
                    mode={exploreMode}
                    onModeChange={lambda (m: str) {
                        exploreMode = m;
                        if m == "repos" {
                            loadProjects();
                        }
                    }}
                    {allProfiles}
                    {followingIds}
                    {myProfileId}
                    {avatars}
                    projects={allProjects}
                    {projectsLoading}
                    onFollow={handleFollow}
                    onUnfollow={handleUnfollow}
                    onViewProfile={handleViewProfile}
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
                    {avatars}
                    onViewProfile={handleViewProfile}
                    onLike={handleLike}
                    onComment={handleComment}
                    onDelete={handleDelete}
                    onRepost={handleRepost}
                />
            } elif activeTab == "profile" and myProfile {
                if editingProfile {
                    <ProfileEditor
                        profile={myProfile.profile}
                        saving={profileSaving}
                        error={profileError}
                        onSave={handleSaveProfile}
                        onCancel={lambda {
                            editingProfile = False;
                            profileError = "";
                        }}
                    />
                } else {
                    <ProfileHeader
                        bundle={myProfile}
                        isMine={True}
                        {avatars}
                        isFollowing={False}
                        onFollow={handleFollow}
                        onUnfollow={handleUnfollow}
                        onStartEdit={lambda {
                            profileError = "";
                            editingProfile = True;
                        }}
                        {avatarBusy}
                        onAvatarFile={handleAvatarFile}
                        onClearAvatar={handleClearAvatar}
                    />
                    if profileError {
                        <p
                            className="px-4 pb-2 text-sm text-destructive"
                            id="lx-profile-error"
                        >
                            {profileError}
                        </p>
                    }
                }
                <ProjectsPanel
                    projects={myProfile.projects or []}
                    isMine={True}
                    {avatars}
                    busy={projectBusy}
                    error={projectError}
                    notice={projectNotice}
                    onAdd={handleAddProject}
                    onRemove={handleRemoveProject}
                    onRescore={handleRescoreProject}
                    onViewOwner={handleViewProfile}
                />
                <div className="border-t border-border">
                    {for tweet in (myProfile.tweets or []) {
                        <TweetCard
                            key={jid(tweet)}
                            {tweet}
                            myUsername={profileUsername}
                            {avatars}
                            onViewProfile={handleViewProfile}
                            onLike={handleLike}
                            onComment={handleComment}
                            onDelete={handleDelete}
                            onRepost={handleRepost}
                        />
                    }}
                </div>
            } elif activeTab == "user" {
                if viewedLoading or viewedProfile is None {
                    <div className="flex justify-center py-16">
                        <div
                            className="size-8 animate-spin rounded-full border-2 border-primary border-t-transparent"
                        />
                    </div>
                } else {
                    <ProfileHeader
                        bundle={viewedProfile}
                        isMine={False}
                        {avatars}
                        isFollowing={jid(viewedProfile.profile) in followingIds}
                        onFollow={handleFollow}
                        onUnfollow={handleUnfollow}
                        onStartEdit={lambda {}}
                        avatarBusy={False}
                        onAvatarFile={lambda (_f: any) {}}
                        onClearAvatar={lambda {}}
                    />
                    <ProjectsPanel
                        projects={viewedProfile.projects or []}
                        isMine={False}
                        {avatars}
                        busy={False}
                        error=""
                        notice=""
                        onAdd={lambda (_u: str) {}}
                        onRemove={lambda (_id: str) {}}
                        onRescore={lambda (_id: str) {}}
                        onViewOwner={handleViewProfile}
                    />
                    <div className="border-t border-border">
                        {for tweet in (viewedProfile.tweets or []) {
                            <TweetCard
                                key={jid(tweet)}
                                {tweet}
                                myUsername={profileUsername}
                                {avatars}
                                onViewProfile={handleViewProfile}
                                onLike={handleLike}
                                onComment={handleComment}
                                onDelete={handleDelete}
                                onRepost={handleRepost}
                            />
                        }}
                    </div>
                }
            }    }
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
            {avatars}
            onFollow={handleFollow}
            onShowMore={lambda { navigate("explore"); }}
            onViewProfile={handleViewProfile}
        />
        <MobileNav {activeTab} {notifCount} onNavigate={navigate}/>
        <Button
            className="fixed bottom-20 right-4 z-40 size-14 rounded-full shadow-lg shadow-primary/30 md:hidden"
            onClick={lambda { navigate("feed"); }}
        >
            <Feather size={22}/>
        </Button>
    </div>
}
