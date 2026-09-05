impl Socialize.loadData -> None {
    result = root spawn setup_profile(
        username=localStorage.getItem("lx_username") or ""
    );
    myProfile = result.reports[0] if result.reports else None;

    feedResult = root spawn load_feed(search_query="");
    tweets = feedResult.reports[0] if feedResult.reports else [];
    feedLoading = False;

    profileResult = root spawn get_profile();
    myProfile = profileResult.reports[0] if profileResult.reports else myProfile;

    profilesResult = root spawn get_all_profiles();
    allProfiles = profilesResult.reports[0] if profilesResult.reports else [];

    trendResult = root spawn get_trending();
    trendingTags = trendResult.reports[0] if trendResult.reports else [];

    total_activity = sum(
        [
            len(t.likes) + len(t.comments)
            for t in (myProfile.tweets if myProfile and myProfile.tweets else [])
        ]
    );
    last_seen_str = localStorage.getItem("lx_activity_total");
    last_seen = int(last_seen_str) if last_seen_str else 0;
    notifCount = total_activity - last_seen if total_activity > last_seen else 0;
    refreshAvatars();
}

impl Socialize.refreshAvatars -> None {
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
}

impl Socialize.handleLogin -> None {
    authError = "";
    if not authUsername.strip() or not authPassword {
        authError = "Please fill in all fields";
        return;
    }
    authLoading = True;
    result: bool = await jacLogin(authUsername, authPassword);
    authLoading = False;
    if result {
        localStorage.setItem("lx_username", authUsername);
        isLoggedIn = True;
        authPassword = "";
        authError = "";
    } else {
        authError = "Invalid username or password";
    }
}

impl Socialize.handleSignup -> None {
    authError = "";
    if not authUsername.strip() or not authPassword {
        authError = "Please fill in all fields";
        return;
    }
    if len(authPassword) < 4 {
        authError = "Password must be at least 4 characters";
        return;
    }
    authLoading = True;
    result: dict[str, any] = await jacSignup(authUsername, authPassword);
    if result["success"] {
        loginResult: bool = await jacLogin(authUsername, authPassword);
        authLoading = False;
        if loginResult {
            localStorage.setItem("lx_username", authUsername);
            isLoggedIn = True;
            authPassword = "";
            authError = "";
        } else {
            isSignup = False;
            authError = "Account created. Please log in.";
        }
    } else {
        authLoading = False;
        authError = str(result["error"] if result["error"] else "Signup failed");
    }
}

impl Socialize.handleLogout -> None {
    jacLogout();
    localStorage.removeItem("lx_username");
    isLoggedIn = False;
    myProfile = None;
    tweets = [];
    allProfiles = [];
    activeTab = "feed";
    authUsername = "";
    authPassword = "";
    avatars = {};
    avatarSeen = {};
    viewedProfile = None;
    allProjects = [];
    editingProfile = False;
}

impl Socialize.postTweet -> None {
    if not composerText.strip() {
        return;
    }
    text = composerText;
    composerText = "";
    root spawn create_tweet(content=text);
    feedResult = root spawn load_feed(search_query="");
    tweets = feedResult.reports[0] if feedResult.reports else [];
    profileResult = root spawn get_profile();
    myProfile = profileResult.reports[0] if profileResult.reports else myProfile;
    trendResult = root spawn get_trending();
    trendingTags = trendResult.reports[0] if trendResult.reports else [];
}

impl Socialize.handleLike(tweetId: str) -> None {
    root spawn like_tweet(tweet_id=tweetId);
    feedResult = root spawn load_feed(search_query=searchQuery);
    tweets = feedResult.reports[0] if feedResult.reports else [];
    if myProfile {
        profileResult = root spawn get_profile();
        myProfile = profileResult.reports[0] if profileResult.reports else myProfile;
    }
    if selectedChannel {
        detailResult = root spawn get_channel_detail(
            channel_id=jid(selectedChannel.channel)
        );
        detail = detailResult.reports[0] if detailResult.reports else None;
        if detail {
            selectedChannel = detail;
            channelPosts = detail.posts or [];
        }
    }
}

impl Socialize.handleComment(tweetId: str, content: str) -> None {
    root spawn add_comment(tweet_id=tweetId, content=content);
    feedResult = root spawn load_feed(search_query=searchQuery);
    tweets = feedResult.reports[0] if feedResult.reports else [];
    if selectedChannel {
        detailResult = root spawn get_channel_detail(
            channel_id=jid(selectedChannel.channel)
        );
        detail = detailResult.reports[0] if detailResult.reports else None;
        if detail {
            selectedChannel = detail;
            channelPosts = detail.posts or [];
        }
    }
}

impl Socialize.handleDelete(tweetId: str) -> None {
    root spawn delete_tweet(tweet_id=tweetId);
    feedResult = root spawn load_feed(search_query=searchQuery);
    tweets = feedResult.reports[0] if feedResult.reports else [];
    profileResult = root spawn get_profile();
    myProfile = profileResult.reports[0] if profileResult.reports else myProfile;
}

impl Socialize.handleFollow(profileId: str) -> None {
    if profileId == "_load" {
        profilesResult = root spawn get_all_profiles();
        allProfiles = profilesResult.reports[0] if profilesResult.reports else [];
        return;
    }
    root spawn follow_user(target_id=profileId);
    profileResult = root spawn get_profile();
    myProfile = profileResult.reports[0] if profileResult.reports else myProfile;
    feedResult = root spawn load_feed(search_query=searchQuery);
    tweets = feedResult.reports[0] if feedResult.reports else [];
    if viewedProfile and jid(viewedProfile.profile) == profileId {
        viewResult = root spawn get_user_profile(
            username=viewedProfile.profile.username
        );
        viewOutcome = viewResult.reports[0] if viewResult.reports else None;
        if viewOutcome and viewOutcome.ok and viewOutcome.bundle {
            viewedProfile = viewOutcome.bundle;
        }
    }
}

impl Socialize.handleUnfollow(profileId: str) -> None {
    root spawn unfollow_user(target_id=profileId);
    profileResult = root spawn get_profile();
    myProfile = profileResult.reports[0] if profileResult.reports else myProfile;
    feedResult = root spawn load_feed(search_query=searchQuery);
    tweets = feedResult.reports[0] if feedResult.reports else [];
    if viewedProfile and jid(viewedProfile.profile) == profileId {
        viewResult = root spawn get_user_profile(
            username=viewedProfile.profile.username
        );
        viewOutcome = viewResult.reports[0] if viewResult.reports else None;
        if viewOutcome and viewOutcome.ok and viewOutcome.bundle {
            viewedProfile = viewOutcome.bundle;
        }
    }
}

impl Socialize.handleSaveProfile(fields: dict[str, str]) -> None {
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
}

impl Socialize.handleAvatarFile(file: any) -> None {
    if not file {
        return;
    }
    avatarBusy = True;
    profileError = "";
    data_url = "";
    try {
        data_url = await shrink_avatar(file);
    } except Exception {
        avatarBusy = False;
        profileError = "That file could not be read as an image";
        return;
    }
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
        myProfile = profileResult.reports[0] if profileResult.reports else myProfile;
        profilesResult = root spawn get_all_profiles();
        allProfiles = profilesResult.reports[0] if profilesResult.reports else [];
    } else {
        profileError = outcome.error
            if outcome and outcome.error
            else "Could not upload that photo";
    }
}

impl Socialize.handleClearAvatar -> None {
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
}

impl Socialize.handleViewProfile(username: str) -> None {
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
    refreshAvatars();
}

impl Socialize.loadProjects -> None {
    projectsLoading = True;
    result = root spawn get_all_projects();
    allProjects = result.reports[0] if result.reports else [];
    projectsLoading = False;
    refreshAvatars();
}

impl Socialize.handleAddProject(url: str) -> None {
    if not url.strip() or projectBusy {
        return;
    }
    projectBusy = True;
    projectError = "";
    projectNotice = "";
    result = root spawn add_project(url=url.strip());
    outcome = result.reports[0] if result.reports else None;
    projectBusy = False;
    if outcome and outcome.ok and outcome.project {
        projectNotice = (
            outcome.project.full
            + " scored "
            + str(outcome.project.score)
            + " points, "
            + outcome.project.belt
            + " belt."
        );
    } elif outcome and outcome.project {
        projectError = project_error_message(outcome.error);
    } else {
        projectError = project_error_message(outcome.error if outcome else "internal");
    }
    profileResult = root spawn get_profile();
    myProfile = profileResult.reports[0] if profileResult.reports else myProfile;
}

impl Socialize.handleRemoveProject(projectId: str) -> None {
    projectError = "";
    projectNotice = "";
    root spawn remove_project(project_id=projectId);
    profileResult = root spawn get_profile();
    myProfile = profileResult.reports[0] if profileResult.reports else myProfile;
    allProjects = [
        p
        for p in allProjects
        if jid(p) != projectId
    ];
}

impl Socialize.handleRescoreProject(projectId: str) -> None {
    if projectBusy {
        return;
    }
    projectBusy = True;
    projectError = "";
    projectNotice = "";
    result = root spawn rescore_project(project_id=projectId);
    outcome = result.reports[0] if result.reports else None;
    projectBusy = False;
    if outcome and outcome.error == "cooldown" {
        projectNotice = project_error_message("cooldown");
    } elif outcome and outcome.ok and outcome.project {
        projectNotice = (
            outcome.project.full
            + " rescored: "
            + str(outcome.project.score)
            + " points."
        );
    } else {
        projectError = project_error_message(outcome.error if outcome else "internal");
    }
    profileResult = root spawn get_profile();
    myProfile = profileResult.reports[0] if profileResult.reports else myProfile;
}

impl Socialize.handleSearch(query: str) -> None {
    feedResult = root spawn load_feed(search_query=query);
    tweets = feedResult.reports[0] if feedResult.reports else [];
}

impl Socialize.handleRepost(tweetId: str, content: str, author: str) -> None {
    display_author = author.split("@")[0] if "@" in author else author;
    composerText = "RT @" + display_author + ": " + content;
    activeTab = "feed";
}

impl Socialize.handleDismissWelcome -> None {
    localStorage.setItem("lx_welcomed", "1");
    showWelcome = False;
}

impl Socialize.handleTrendClick(tag: str) -> None {
    searchQuery = tag;
    handleSearch(tag);
    activeTab = "feed";
}

impl Socialize.navigate(tab: str) -> None {
    activeTab = tab;
    if tab != "profile" {
        editingProfile = False;
        profileError = "";
    }
    if tab == "explore" and exploreMode == "repos" {
        loadProjects();
    }
    if tab == "feed" and searchQuery {
        searchQuery = "";
        handleSearch("");
    }
    if tab == "channels" {
        loadChannels();
    }
    if tab == "profile" {
        total_activity = sum(
            [
                len(t.likes) + len(t.comments)
                for t in (myProfile.tweets if myProfile and myProfile.tweets else [])
            ]
        );
        localStorage.setItem("lx_activity_total", str(total_activity));
        notifCount = 0;
    }
}

impl Socialize.loadChannels -> None {
    channelsLoading = True;
    result = root spawn get_channels();
    channels = result.reports[0] if result.reports else [];
    channelsLoading = False;
}

impl Socialize.handleCreateChannel(name: str, description: str) -> None {
    if not name.strip() {
        return;
    }
    root spawn create_channel(name=name.strip(), description=description.strip());
    result = root spawn get_channels();
    channels = result.reports[0] if result.reports else [];
}

impl Socialize.handleJoinChannel(channelId: str) -> None {
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
}

impl Socialize.handleLeaveChannel(channelId: str) -> None {
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
}

impl Socialize.handleSelectChannel(channelId: str) -> None {
    detailResult = root spawn get_channel_detail(channel_id=channelId);
    detail = detailResult.reports[0] if detailResult.reports else None;
    if detail {
        selectedChannel = detail;
        channelPosts = detail.posts or [];
    }
}

impl Socialize.handleChannelPost(text: str) -> None {
    if not text.strip() or not selectedChannel {
        return;
    }
    root spawn create_channel_tweet(
        channel_id=jid(selectedChannel.channel), content=text
    );
    detailResult = root spawn get_channel_detail(
        channel_id=jid(selectedChannel.channel)
    );
    detail = detailResult.reports[0] if detailResult.reports else None;
    if detail {
        selectedChannel = detail;
        channelPosts = detail.posts or [];
    }
}

impl Socialize.handleBackToChannels -> None {
    selectedChannel = None;
    channelPosts = [];
}
