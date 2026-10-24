impl useJacYac.onBridgeError(e: BridgeError) -> None {
    if isinstance(e, BridgeRejected) and e.status == 401 {
        if not jacIsLoggedIn() {
            logout();
        }
        return;
    }
    bridgeMessage = bridge_error(e);
}

impl useJacYac.loadData -> None {
    try {
        feedLoading = True;
        result = root spawn setup_profile(username=stored_username());
        myProfile = result.reports[0] if result.reports else None;
        await refreshSocial();
        profilesResult = root spawn get_all_profiles();
        allProfiles = profilesResult.reports[0] if profilesResult.reports else [];
        await refreshAvatars();
    } except BridgeError as e {
        onBridgeError(e);
    } except Exception {
        bridgeMessage = "Something went wrong. Please try again.";
    } finally {
        feedLoading = False;
    }
}

impl useJacYac.refreshAvatars -> None {
    try {
        known: list[Profile] = list(allProfiles);
        if myProfile {
            known.append(myProfile.profile);
        }
        if viewedProfile {
            known.append(viewedProfile.profile);
        }
        next_map: dict[str, str] = {};
        next_seen: dict[str, str] = {};
        wanted: list[str] = [];
        for p in known {
            if p.avatar_v == "" {
                continue;
            }
            next_seen[p.username] = p.avatar_v;
            if avatarSeen.get(p.username) == p.avatar_v and p.username in avatars {
                next_map[p.username] = avatars[p.username];
            } elif p.username not in wanted {
                wanted.append(p.username);
            }
        }
        if wanted {
            result = root spawn get_avatars(usernames=wanted);
            found: dict[str, str] = result.reports[0] if result.reports else {};
            for u in wanted {
                if u in found {
                    next_map[u] = found[u];
                }
            }
        }
        avatars = next_map;
        avatarSeen = next_seen;
    } except BridgeError as e {
        onBridgeError(e);
    } except Exception {
        bridgeMessage = "Something went wrong. Please try again.";
    }
}

impl useJacYac.postTweet -> None {
    if posting or not valid_post(composerText) {
        return;
    }
    try {
        posting = True;
        result: any = root spawn create_tweet(content=composerText.strip());
        if result.reports[0]?.message {
            bridgeMessage = result.reports[0].message;
            return;
        }
        composerText = "";
        await refreshSocial();
    } except BridgeError as e {
        onBridgeError(e);
    } except Exception {
        bridgeMessage = "Something went wrong. Please try again.";
    } finally {
        posting = False;
    }
}

impl useJacYac.handleLike(tweetId: str) -> None {
    try {
        root spawn like_tweet(tweet_id=tweetId);
        await refreshSocial();
    } except BridgeError as e {
        onBridgeError(e);
    } except Exception {
        bridgeMessage = "Something went wrong. Please try again.";
    }
}

impl useJacYac.handleComment(tweetId: str, content: str) -> bool {
    try {
        if not valid_post(content) {
            return False;
        }
        result: any = root spawn add_comment(tweet_id=tweetId, content=content.strip());
        if result.reports[0]?.message {
            bridgeMessage = result.reports[0].message;
            return False;
        }
        await refreshSocial();
        return True;
    } except BridgeError as e {
        onBridgeError(e);
    } except Exception {
        bridgeMessage = "Something went wrong. Please try again.";
    }
    return False;
}

impl useJacYac.handleDelete(tweetId: str) -> None {
    try {
        root spawn delete_tweet(tweet_id=tweetId);
        await refreshSocial();
    } except BridgeError as e {
        onBridgeError(e);
    } except Exception {
        bridgeMessage = "Something went wrong. Please try again.";
    }
}

impl useJacYac.handleFollow(profileId: str) -> None {
    try {
        root spawn follow_user(target_id=profileId);
        await refreshSocial();
    } except BridgeError as e {
        onBridgeError(e);
    } except Exception {
        bridgeMessage = "Something went wrong. Please try again.";
    }
}

impl useJacYac.handleUnfollow(profileId: str) -> None {
    try {
        root spawn unfollow_user(target_id=profileId);
        await refreshSocial();
    } except BridgeError as e {
        onBridgeError(e);
    } except Exception {
        bridgeMessage = "Something went wrong. Please try again.";
    }
}

impl useJacYac.handleSaveProfile(fields: dict[str, str]) -> None {
    try {
        profileSaving = True;
        profileError = "";
        result = root spawn update_profile(
            display_name=fields["display_name"] or "",
            bio=fields["bio"] or "",
            location=fields["location"] or "",
            website=fields["website"] or "",
            github=fields["github"] or ""
        );
        outcome = result.reports[0] if result.reports else None;
        profileSaving = False;
        if outcome and outcome.ok and outcome.bundle {
            myProfile = outcome.bundle;
            editingProfile = False;
            profilesResult = root spawn get_all_profiles();
            allProfiles = profilesResult.reports[0] if profilesResult.reports else [];
        } else {
            profileError = outcome.error
                if outcome and outcome.error
                else "Could not save your profile";
        }
    } except BridgeError as e {
        onBridgeError(e);
    } except Exception {
        bridgeMessage = "Something went wrong. Please try again.";
    } finally {
        profileSaving = False;
    }
}

impl useJacYac.handleClearAvatar -> None {
    try {
        avatarBusy = True;
        root spawn clear_avatar();
        avatarBusy = False;
        me = myProfile.profile.username if myProfile else "";
        next_map: dict[str, str] = {};
        for u in avatars {
            if u != me {
                next_map[u] = avatars[u];
            }
        }
        avatars = next_map;
        profileResult = root spawn get_profile();
        myProfile = profileResult.reports[0] if profileResult.reports else myProfile;
        profilesResult = root spawn get_all_profiles();
        allProfiles = profilesResult.reports[0] if profilesResult.reports else [];
    } except BridgeError as e {
        onBridgeError(e);
    } except Exception {
        bridgeMessage = "Something went wrong. Please try again.";
    } finally {
        avatarBusy = False;
    }
}

impl useJacYac.handleViewProfile(username: str) -> None {
    try {
        if not username {
            return;
        }
        me = myProfile.profile.username if myProfile else "";
        if username == me {
            navigate("profile");
            return;
        }
        viewedLoading = True;
        activeTab = "user";
        result = root spawn get_user_profile(username=username);
        outcome = result.reports[0] if result.reports else None;
        if outcome and outcome.ok and outcome.bundle {
            viewedProfile = outcome.bundle;
        } else {
            viewedProfile = None;
            activeTab = "explore";
        }
        viewedLoading = False;
        await refreshAvatars();
    } except BridgeError as e {
        onBridgeError(e);
    } except Exception {
        bridgeMessage = "Something went wrong. Please try again.";
    } finally {
        viewedLoading = False;
    }
}

impl useJacYac.handleSearch(query: str) -> None {
    try {
        searchQuery = query;
        feedResult = root spawn load_feed(search_query=query);
        tweets = feedResult.reports[0] if feedResult.reports else [];
    } except BridgeError as e {
        onBridgeError(e);
    } except Exception {
        bridgeMessage = "Something went wrong. Please try again.";
    }
}

impl useJacYac.handleRepost(tweetId: str, content: str, author: str) -> None {
    display_author = author.split("@")[0] if "@" in author else author;
    composerText = "RT @" + display_author + ": " + content;
    activeTab = "feed";
}

impl useJacYac.handleDismissWelcome -> None {
    __setLocalStorage("lx_welcomed", "1");
    showWelcome = False;
}

impl useJacYac.handleTrendClick(tag: str) -> None {
    try {
        searchQuery = tag;
        await handleSearch(tag);
        activeTab = "feed";
    } except BridgeError as e {
        onBridgeError(e);
    } except Exception {
        bridgeMessage = "Something went wrong. Please try again.";
    }
}

impl useJacYac.navigate(tab: str) -> None {
    try {
        activeTab = tab;
        if tab != "profile" {
            editingProfile = False;
            profileError = "";
        }
        if tab == "explore" {
            result = root spawn get_all_profiles();
            allProfiles = result.reports[0] if result.reports else [];
            await refreshAvatars();
        }
        if tab == "feed" and searchQuery {
            searchQuery = "";
            await handleSearch("");
        }
        if tab == "channels" {
            await loadChannels();
        }
        if tab == "profile" {
            total_activity = sum(
                [
                    len(t.likes) + len(t.comments)
                    for t in (
                        myProfile.tweets if myProfile and myProfile.tweets else []
                    )
                ]
            );
            __setLocalStorage("lx_activity_total", str(total_activity));
            notifCount = 0;
        }
    } except BridgeError as e {
        onBridgeError(e);
    } except Exception {
        bridgeMessage = "Something went wrong. Please try again.";
    }
}

impl useJacYac.loadChannels -> None {
    try {
        channelsLoading = True;
        result = root spawn get_channels();
        channels = result.reports[0] if result.reports else [];
        channelsLoading = False;
    } except BridgeError as e {
        onBridgeError(e);
    } except Exception {
        bridgeMessage = "Something went wrong. Please try again.";
    } finally {
        channelsLoading = False;
    }
}

impl useJacYac.handleCreateChannel(name: str, description: str) -> None {
    try {
        if not name.strip() {
            return;
        }
        root spawn create_channel(name=name.strip(), description=description.strip());
        result = root spawn get_channels();
        channels = result.reports[0] if result.reports else [];
    } except BridgeError as e {
        onBridgeError(e);
    } except Exception {
        bridgeMessage = "Something went wrong. Please try again.";
    }
}

impl useJacYac.handleJoinChannel(channelId: str) -> None {
    try {
        root spawn join_channel(channel_id=channelId);
        result = root spawn get_channels();
        channels = result.reports[0] if result.reports else [];
        if selectedChannel and jid(selectedChannel.channel) == channelId {
            detailResult = root spawn get_channel_detail(channel_id=channelId);
            detail = detailResult.reports[0] if detailResult.reports else None;
            if detail {
                selectedChannel = detail;
                channelPosts = detail.posts or [];
            }
        }
    } except BridgeError as e {
        onBridgeError(e);
    } except Exception {
        bridgeMessage = "Something went wrong. Please try again.";
    }
}

impl useJacYac.handleLeaveChannel(channelId: str) -> None {
    try {
        root spawn leave_channel(channel_id=channelId);
        result = root spawn get_channels();
        channels = result.reports[0] if result.reports else [];
        if selectedChannel and jid(selectedChannel.channel) == channelId {
            detailResult = root spawn get_channel_detail(channel_id=channelId);
            detail = detailResult.reports[0] if detailResult.reports else None;
            if detail {
                selectedChannel = detail;
                channelPosts = detail.posts or [];
            }
        }
    } except BridgeError as e {
        onBridgeError(e);
    } except Exception {
        bridgeMessage = "Something went wrong. Please try again.";
    }
}

impl useJacYac.handleSelectChannel(channelId: str) -> None {
    try {
        detailResult = root spawn get_channel_detail(channel_id=channelId);
        detail = detailResult.reports[0] if detailResult.reports else None;
        if detail {
            selectedChannel = detail;
            channelPosts = detail.posts or [];
        }
    } except BridgeError as e {
        onBridgeError(e);
    } except Exception {
        bridgeMessage = "Something went wrong. Please try again.";
    }
}

impl useJacYac.handleChannelPost(text: str) -> bool {
    if not selectedChannel or not valid_post(text) or posting {
        return False;
    }
    try {
        posting = True;
        result: any = root spawn create_channel_tweet(
            channel_id=jid(selectedChannel.channel), content=text.strip()
        );
        if result.reports[0]?.message {
            bridgeMessage = result.reports[0].message;
            return False;
        }
        await refreshSocial();
        return True;
    } except BridgeError as e {
        onBridgeError(e);
    } except Exception {
        bridgeMessage = "Something went wrong. Please try again.";
    } finally {
        posting = False;
    }
    return False;
}

impl useJacYac.handleBackToChannels -> None {
    selectedChannel = None;
    channelPosts = [];
}

impl useJacYac.refreshSocial -> None {
    try {
        feedResult = root spawn load_feed(search_query=searchQuery);
        tweets = feedResult.reports[0] if feedResult.reports else [];
        profileResult = root spawn get_profile();
        myProfile = profileResult.reports[0] if profileResult.reports else None;
        total = sum(
            [
                len(t.likes) + len(t.comments)
                for t in (myProfile.tweets if myProfile else [])
            ]
        );
        seen = __getLocalStorage("lx_activity_total");
        last_seen = int(seen) if seen else 0;
        notifCount = max(0, total - last_seen);
        trendResult = root spawn get_trending();
        trendingTags = trendResult.reports[0] if trendResult.reports else [];
        if selectedChannel {
            await handleSelectChannel(jid(selectedChannel.channel));
        }
        if viewedProfile {
            result = root spawn get_user_profile(
                username=viewedProfile.profile.username
            );
            outcome = result.reports[0] if result.reports else None;
            viewedProfile = outcome.bundle if outcome and outcome.ok else None;
        }
    } except BridgeError as e {
        onBridgeError(e);
    } except Exception {
        bridgeMessage = "Something went wrong. Please try again.";
    }
}

impl useJacYac.handleRefresh -> None {
    bridgeMessage = "";
    refreshing = True;
    try {
        await loadData();
        await loadChannels();
    } finally {
        refreshing = False;
    }
}

impl useJacYac.handleSaveBio(bio: str) -> None {
    try {
        if not myProfile {
            return;
        }
        await handleSaveProfile(
            {
                "display_name": myProfile.profile.display_name,
                "bio": bio,
                "location": myProfile.profile.location,
                "website": myProfile.profile.website,
                "github": myProfile.profile.github
            }
        );
    } except BridgeError as e {
        onBridgeError(e);
    } except Exception {
        bridgeMessage = "Something went wrong. Please try again.";
    }
}

impl useJacYac.handleAvatarData(data_url: str) -> None {
    try {
        avatarBusy = True;
        profileError = "";
        result = root spawn set_avatar(data_url=data_url);
        outcome = result.reports[0] if result.reports else None;
        avatarBusy = False;
        me = myProfile.profile.username if myProfile else "";
        if outcome and outcome.ok {
            next_map: dict[str, str] = {** avatars};
            next_seen: dict[str, str] = {** avatarSeen};
            next_map[me] = outcome.avatar_url;
            next_seen[me] = outcome.avatar_v;
            avatars = next_map;
            avatarSeen = next_seen;
            profileResult = root spawn get_profile();
            myProfile = profileResult.reports[0]
                if profileResult.reports
                else myProfile;
            profilesResult = root spawn get_all_profiles();
            allProfiles = profilesResult.reports[0] if profilesResult.reports else [];
        } else {
            profileError = outcome.error
                if outcome and outcome.error
                else "Could not upload that photo";
        }
    } except BridgeError as e {
        onBridgeError(e);
    } except Exception {
        bridgeMessage = "Something went wrong. Please try again.";
    } finally {
        avatarBusy = False;
    }
}

impl useJacYac -> JacYacState {
    session = useSession();
    has activeTab: str = "feed",
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
        trendingTags: list[TrendingTag] = [],
        notifCount: int = 0,
        showWelcome: bool = False,
        channels: list[ChannelBundle] = [],
        channelsLoading: bool = False,
        selectedChannel: ChannelBundle | None = None,
        channelPosts: list[Tweet] = [],
        posting: bool = False,
        refreshing: bool = False,
        bridgeMessage: str = "";

    can with [session.loggedIn] entry {
        if session.loggedIn {
            showWelcome = not __getLocalStorage("lx_welcomed");
            loadData();
        }
    }
    def onBridgeError(e: BridgeError) -> None;
    async def loadData -> None;
    async def refreshAvatars -> None;
    async def postTweet -> None;
    async def handleLike(tweetId: str) -> None;
    async def handleComment(tweetId: str, content: str) -> bool;
    async def handleDelete(tweetId: str) -> None;
    async def handleFollow(profileId: str) -> None;
    async def handleUnfollow(profileId: str) -> None;
    async def handleSaveProfile(fields: dict[str, str]) -> None;
    async def handleClearAvatar -> None;
    async def handleViewProfile(username: str) -> None;
    async def handleSearch(query: str) -> None;
    def handleRepost(tweetId: str, content: str, author: str) -> None;
    def handleDismissWelcome -> None;
    async def handleTrendClick(tag: str) -> None;
    async def navigate(tab: str) -> None;
    async def loadChannels -> None;
    async def handleCreateChannel(name: str, description: str) -> None;
    async def handleJoinChannel(channelId: str) -> None;
    async def handleLeaveChannel(channelId: str) -> None;
    async def handleSelectChannel(channelId: str) -> None;
    async def handleChannelPost(text: str) -> bool;
    def handleBackToChannels -> None;
    async def refreshSocial -> None;
    async def handleRefresh -> None;
    async def handleSaveBio(bio: str) -> None;
    async def handleAvatarData(data_url: str) -> None;

    def logout {
        session.logout();
        activeTab = "feed";
        myProfile = None;
        tweets = [];
        feedLoading = True;
        composerText = "";
        searchQuery = "";
        allProfiles = [];
        avatars = {};
        avatarSeen = {};
        editingProfile = False;
        profileSaving = False;
        profileError = "";
        avatarBusy = False;
        viewedProfile = None;
        viewedLoading = False;
        trendingTags = [];
        notifCount = 0;
        showWelcome = False;
        channels = [];
        channelsLoading = False;
        selectedChannel = None;
        channelPosts = [];
        posting = False;
        refreshing = False;
        bridgeMessage = "";
    }

    return JacYacState(
        session=session,
        activeTab=activeTab,
        myProfile=myProfile,
        tweets=tweets,
        feedLoading=feedLoading,
        composerText=composerText,
        searchQuery=searchQuery,
        allProfiles=allProfiles,
        avatars=avatars,
        avatarSeen=avatarSeen,
        editingProfile=editingProfile,
        profileSaving=profileSaving,
        profileError=profileError,
        avatarBusy=avatarBusy,
        viewedProfile=viewedProfile,
        viewedLoading=viewedLoading,
        trendingTags=trendingTags,
        notifCount=notifCount,
        showWelcome=showWelcome,
        channels=channels,
        channelsLoading=channelsLoading,
        selectedChannel=selectedChannel,
        channelPosts=channelPosts,
        posting=posting,
        refreshing=refreshing,
        bridgeMessage=bridgeMessage,
        loadData=loadData,
        refreshAvatars=refreshAvatars,
        postTweet=postTweet,
        handleLike=handleLike,
        handleComment=handleComment,
        handleDelete=handleDelete,
        handleFollow=handleFollow,
        handleUnfollow=handleUnfollow,
        handleSaveProfile=handleSaveProfile,
        handleClearAvatar=handleClearAvatar,
        handleViewProfile=handleViewProfile,
        handleSearch=handleSearch,
        handleRepost=handleRepost,
        handleDismissWelcome=handleDismissWelcome,
        handleTrendClick=handleTrendClick,
        navigate=navigate,
        loadChannels=loadChannels,
        handleCreateChannel=handleCreateChannel,
        handleJoinChannel=handleJoinChannel,
        handleLeaveChannel=handleLeaveChannel,
        handleSelectChannel=handleSelectChannel,
        handleChannelPost=handleChannelPost,
        handleBackToChannels=handleBackToChannels,
        refreshSocial=refreshSocial,
        handleRefresh=handleRefresh,
        handleSaveBio=handleSaveBio,
        handleAvatarData=handleAvatarData,
        setActiveTab=lambda (value: str) { activeTab = value; },
        setComposerText=lambda (value: str) { composerText = value; },
        setSearchQuery=lambda (value: str) { searchQuery = value; },
        setEditingProfile=lambda (value: bool) { editingProfile = value; },
        setProfileError=lambda (value: str) { profileError = value; },
        logout=logout,
        dismissError=lambda { bridgeMessage = ""; },
        reportError=lambda (message: str) { bridgeMessage = message; }
    );
}
