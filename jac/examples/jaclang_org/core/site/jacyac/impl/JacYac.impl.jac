impl JacYac(initialTab: str = "feed") -> JsxElement {
    model = useJacYac();
    loc = useLocation();
    path_parts = loc.pathname.split("/");
    focus = path_parts[3]
        if len(path_parts) > 3 and path_parts[2] == model.activeTab
        else "";
    claw = useClaw(model.activeTab, focus);
    can with entry {
        if initialTab != "feed" {
            model.navigate(initialTab);
        }
    }
    async def handleAvatarFile(file: any) -> None {
        if not file {
            return;
        }
        try {
            await model.handleAvatarData(await shrink_avatar(file));
        } except Exception {
            model.reportError("That file could not be read as an image");
        }
    }
    if model.session.checking {
        return
            <div
                className="flex min-h-[calc(100vh-4rem)] items-center justify-center bg-background"
            >
                <div
                    className="size-8 animate-spin rounded-full border-2 border-primary border-t-transparent"
                />
            </div>;
    }

    if not model.session.loggedIn and model.activeTab not in PUBLIC_TABS {
        return
            <AuthForm
                isSignup={model.session.signup}
                username={model.session.username}
                email={model.session.email}
                password={model.session.password}
                error={model.session.error}
                loading={model.session.busy}
                onUsernameChange={lambda (e: ChangeEvent) { model.session.setUsername(
                    e.target.value
                ); }}
                onEmailChange={lambda (e: ChangeEvent) { model.session.setEmail(
                    e.target.value
                ); }}
                onPasswordChange={lambda (e: ChangeEvent) { model.session.setPassword(
                    e.target.value
                ); }}
                onSubmit={lambda (e: FormEvent) {
                    e.preventDefault();
                    model.session.submit();
                }}
                onToggleMode={model.session.toggleMode}
                githubEnabled={model.session.githubEnabled}
                onGithub={model.session.githubLogin}
            />;
    }

    profileUsername = model.myProfile.profile.username if model.myProfile else "";
    displayUsername = name_of(
        model.myProfile.profile.display_name, model.myProfile.profile.username
    )
        if model.myProfile
        else "";
    profileAvatar = avatar_of(model.avatars, profileUsername);
    myProfileId = jid(model.myProfile.profile) if model.myProfile else "";
    followingIds = [
        jid(f)
        for f in (
            model.myProfile.following
                if model.myProfile and model.myProfile.following
                else []
        )
    ];
    toFollow = [
        u
        for u in model.allProfiles
        if jid(u) not in followingIds and jid(u) != myProfileId
    ];
    viewedName = name_of(
        model.viewedProfile.profile.display_name, model.viewedProfile.profile.username
    )
        if model.viewedProfile
        else "Profile";
    tab_title = TAB_TITLES.get(model.activeTab, viewedName);

    <div
        className="mx-auto flex min-h-[calc(100vh-4rem)] w-full max-w-7xl bg-background text-foreground"
    >
        <Sidebar
            activeTab={model.activeTab}
            {displayUsername}
            {profileUsername}
            {profileAvatar}
            notifCount={model.notifCount}
            onNavigate={model.navigate}
            onLogout={model.logout}
        />
        <main
            className="min-h-[calc(100vh-4rem)] min-w-0 flex-1 border-x border-border pb-20 md:pb-0"
        >
            <header
                className="sticky top-16 z-30 flex items-center gap-2 border-b border-border bg-background/80 px-4 py-3 backdrop-blur-lg"
            >
                {if model.activeTab == "user" {
                    <Button
                        variant="ghost"
                        size="icon"
                        className="size-8 rounded-full"
                        id="lx-back"
                        onClick={lambda { model.navigate("explore"); }}
                    >
                        <ArrowLeft size={18}/>
                    </Button>
                }}
                <span className="font-display text-xl font-extrabold" id="lx-tab-title">
                    {tab_title}
                </span>
            </header>
            {if model.bridgeMessage {
                <div
                    role="alert"
                    className="flex items-center gap-3 border-b border-border p-4 text-sm"
                >
                    <span>{model.bridgeMessage}</span>
                    <Button variant="outline" onClick={model.handleRefresh}>
                        Refresh
                    </Button>
                    <Button variant="ghost" onClick={model.dismissError}>
                        Dismiss
                    </Button>
                </div>
            }}
            {if model.activeTab == "ninjaclaw" {
                <NinjaclawTab model={claw} {focus}/>
            } elif model.activeTab == "tutorials" {
                <TutorialsTab model={claw} {focus}/>
            } elif model.activeTab == "feed" {
                <FeedTab
                    showWelcome={model.showWelcome}
                    onDismissWelcome={model.handleDismissWelcome}
                    {profileAvatar}
                    {profileUsername}
                    composerText={model.composerText}
                    onComposerChange={lambda (v: str) { model.setComposerText(v); }}
                    onPost={model.postTweet}
                    posting={model.posting}
                    feedLoading={model.feedLoading}
                    tweets={model.tweets}
                    avatars={model.avatars}
                    onViewProfile={model.handleViewProfile}
                    onLike={model.handleLike}
                    onComment={model.handleComment}
                    onDelete={model.handleDelete}
                    onRepost={model.handleRepost}
                />
            } elif model.activeTab == "explore" {
                <ExploreTab
                    allProfiles={model.allProfiles}
                    {followingIds}
                    {myProfileId}
                    avatars={model.avatars}
                    onFollow={model.handleFollow}
                    onUnfollow={model.handleUnfollow}
                    onViewProfile={model.handleViewProfile}
                />
            } elif model.activeTab == "channels" {
                <ChannelsTab
                    channels={model.channels}
                    channelsLoading={model.channelsLoading}
                    selectedChannel={model.selectedChannel}
                    channelPosts={model.channelPosts}
                    {profileAvatar}
                    {profileUsername}
                    onCreateChannel={model.handleCreateChannel}
                    onJoinChannel={model.handleJoinChannel}
                    onLeaveChannel={model.handleLeaveChannel}
                    onSelectChannel={model.handleSelectChannel}
                    onChannelPost={model.handleChannelPost}
                    onBackToChannels={model.handleBackToChannels}
                    avatars={model.avatars}
                    onViewProfile={model.handleViewProfile}
                    onLike={model.handleLike}
                    onComment={model.handleComment}
                    onDelete={model.handleDelete}
                    onRepost={model.handleRepost}
                />
            } elif model.activeTab == "profile" and model.myProfile {
                if model.editingProfile {
                    <ProfileEditor
                        profile={model.myProfile.profile}
                        saving={model.profileSaving}
                        error={model.profileError}
                        onSave={model.handleSaveProfile}
                        onCancel={lambda {
                            model.setEditingProfile(False);
                            model.setProfileError("");
                        }}
                    />
                } else {
                    <ProfileHeader
                        bundle={model.myProfile}
                        isMine={True}
                        avatars={model.avatars}
                        isFollowing={False}
                        onFollow={model.handleFollow}
                        onUnfollow={model.handleUnfollow}
                        onStartEdit={lambda {
                            model.setProfileError("");
                            model.setEditingProfile(True);
                        }}
                        avatarBusy={model.avatarBusy}
                        onAvatarFile={handleAvatarFile}
                        onClearAvatar={model.handleClearAvatar}
                    />
                    if model.profileError {
                        <p
                            className="px-4 pb-2 text-sm text-destructive"
                            id="lx-profile-error"
                        >
                            profileError={model.profileError}
                        </p>
                    }
                }
                <div className="border-t border-border">
                    {for tweet in (model.myProfile.tweets or []) {
                        <TweetCard
                            key={jid(tweet)}
                            {tweet}
                            myUsername={profileUsername}
                            avatars={model.avatars}
                            onViewProfile={model.handleViewProfile}
                            onLike={model.handleLike}
                            onComment={model.handleComment}
                            onDelete={model.handleDelete}
                            onRepost={model.handleRepost}
                        />
                    }}
                </div>
            } elif model.activeTab == "user" {
                if model.viewedLoading or model.viewedProfile is None {
                    <div className="flex justify-center py-16">
                        <div
                            className="size-8 animate-spin rounded-full border-2 border-primary border-t-transparent"
                        />
                    </div>
                } else {
                    <ProfileHeader
                        bundle={model.viewedProfile}
                        isMine={False}
                        avatars={model.avatars}
                        isFollowing={jid(model.viewedProfile.profile) in followingIds}
                        onFollow={model.handleFollow}
                        onUnfollow={model.handleUnfollow}
                        onStartEdit={lambda {}}
                        avatarBusy={False}
                        onAvatarFile={lambda (_f: any) {}}
                        onClearAvatar={lambda {}}
                    />
                    <div className="border-t border-border">
                        {for tweet in (model.viewedProfile.tweets or []) {
                            <TweetCard
                                key={jid(tweet)}
                                {tweet}
                                myUsername={profileUsername}
                                avatars={model.avatars}
                                onViewProfile={model.handleViewProfile}
                                onLike={model.handleLike}
                                onComment={model.handleComment}
                                onDelete={model.handleDelete}
                                onRepost={model.handleRepost}
                            />
                        }}
                    </div>
                }
            }      }
        </main>
        <RightSidebar
            searchQuery={model.searchQuery}
            onSearchChange={lambda (v: str) { model.setSearchQuery(v); }}
            onSearch={model.handleSearch}
            onClearSearch={lambda {
                model.setSearchQuery("");
                model.handleSearch("");
            }}
            trendingTags={model.trendingTags}
            onTrendClick={model.handleTrendClick}
            {toFollow}
            avatars={model.avatars}
            onFollow={model.handleFollow}
            onShowMore={lambda { model.navigate("explore"); }}
            onViewProfile={model.handleViewProfile}
        />
        <MobileNav
            activeTab={model.activeTab}
            notifCount={model.notifCount}
            onNavigate={model.navigate}
        />
        <Button
            className="fixed bottom-20 right-4 z-40 size-14 rounded-full shadow-lg shadow-primary/30 md:hidden"
            onClick={lambda { model.navigate("feed"); }}
        >
            <Feather size={22}/>
        </Button>
    </div>
}
