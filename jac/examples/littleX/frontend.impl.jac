"""Little X - Frontend function implementations."""

impl app.loadData -> None {
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
}

impl app.handleLogin -> None {
    authError = "";
    if not authUsername.strip() or not authPassword {
        authError = "Please fill in all fields";
        return;
    }
    authLoading = True;
    result: any = await jacLogin(authUsername, authPassword);
    authLoading = False;
    if result and (result["ok"] or result == True) {
        localStorage.setItem("lx_username", authUsername);
        isLoggedIn = True;
        authPassword = "";
        authError = "";
    } else {
        authError = str(
            result["error"]["message"]
                if result and result["error"] and result["error"]["message"]
                else "Invalid username or password"
        );
    }
}

impl app.handleSignup -> None {
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
    result: any = await jacSignup(authUsername, authPassword);
    if result["ok"] or result["success"] {
        # jacSignup only registers the account; establish a session by
        # logging in so the first walker calls aren't rejected with 401.
        loginResult: any = await jacLogin(authUsername, authPassword);
        authLoading = False;
        if loginResult and (loginResult["ok"] or loginResult == True) {
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
        authError = str(
            result["error"]["message"]
                if result["error"] and result["error"]["message"]
                else (result["error"] if result["error"] else "Signup failed")
        );
    }
}

impl app.handleLogout -> None {
    jacLogout();
    localStorage.removeItem("lx_username");
    isLoggedIn = False;
    myProfile = None;
    tweets = [];
    allProfiles = [];
    activeTab = "feed";
    authUsername = "";
    authPassword = "";
}

impl app.postTweet -> None {
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

impl app.handleLike(tweetId: str) -> None {
    root spawn like_tweet(tweet_id=tweetId);
    feedResult = root spawn load_feed(search_query=searchQuery);
    tweets = feedResult.reports[0] if feedResult.reports else [];
    if myProfile {
        profileResult = root spawn get_profile();
        myProfile = profileResult.reports[0] if profileResult.reports else myProfile;
    }
    if selectedChannel {
        detailResult = root spawn get_channel_detail(channel_id=selectedChannel.id);
        detail = detailResult.reports[0] if detailResult.reports else None;
        if detail {
            selectedChannel = detail;
            channelPosts = detail.posts or [];
        }
    }
}

impl app.handleComment(tweetId: str, content: str) -> None {
    root spawn add_comment(tweet_id=tweetId, content=content);
    feedResult = root spawn load_feed(search_query=searchQuery);
    tweets = feedResult.reports[0] if feedResult.reports else [];
    if selectedChannel {
        detailResult = root spawn get_channel_detail(channel_id=selectedChannel.id);
        detail = detailResult.reports[0] if detailResult.reports else None;
        if detail {
            selectedChannel = detail;
            channelPosts = detail.posts or [];
        }
    }
}

impl app.handleDelete(tweetId: str) -> None {
    root spawn delete_tweet(tweet_id=tweetId);
    feedResult = root spawn load_feed(search_query=searchQuery);
    tweets = feedResult.reports[0] if feedResult.reports else [];
    profileResult = root spawn get_profile();
    myProfile = profileResult.reports[0] if profileResult.reports else myProfile;
}

impl app.handleFollow(profileId: str) -> None {
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
}

impl app.handleUnfollow(profileId: str) -> None {
    root spawn unfollow_user(target_id=profileId);
    profileResult = root spawn get_profile();
    myProfile = profileResult.reports[0] if profileResult.reports else myProfile;
    feedResult = root spawn load_feed(search_query=searchQuery);
    tweets = feedResult.reports[0] if feedResult.reports else [];
}

impl app.handleSaveBio -> None {
    uname = myProfile.username if myProfile else "";
    root spawn setup_profile(username=uname, bio=bioText);
    profileResult = root spawn get_profile();
    myProfile = profileResult.reports[0] if profileResult.reports else myProfile;
    editingBio = False;
}

impl app.handleSearch(query: str) -> None {
    feedResult = root spawn load_feed(search_query=query);
    tweets = feedResult.reports[0] if feedResult.reports else [];
}

impl app.handleRepost(tweetId: str, content: str, author: str) -> None {
    display_author = author.split("@")[0] if "@" in author else author;
    composerText = "RT @" + display_author + ": " + content;
    activeTab = "feed";
}

impl app.handleDismissWelcome -> None {
    localStorage.setItem("lx_welcomed", "1");
    showWelcome = False;
}

impl app.handleTrendClick(tag: str) -> None {
    searchQuery = tag;
    handleSearch(tag);
    activeTab = "feed";
}

# Single entry point for tab switching -- consolidates the per-tab side
# effects (search reset, channel load, profile activity bookkeeping) that
# used to be duplicated across the desktop and mobile nav bars.
impl app.navigate(tab: str) -> None {
    activeTab = tab;
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

impl app.loadChannels -> None {
    channelsLoading = True;
    result = root spawn get_channels();
    channels = result.reports[0] if result.reports else [];
    channelsLoading = False;
}

impl app.handleCreateChannel(name: str, description: str) -> None {
    if not name.strip() {
        return;
    }
    root spawn create_channel(name=name.strip(), description=description.strip());
    result = root spawn get_channels();
    channels = result.reports[0] if result.reports else [];
}

impl app.handleJoinChannel(channelId: str) -> None {
    root spawn join_channel(channel_id=channelId);
    result = root spawn get_channels();
    channels = result.reports[0] if result.reports else [];
    if selectedChannel and selectedChannel.id == channelId {
        detailResult = root spawn get_channel_detail(channel_id=channelId);
        detail = detailResult.reports[0] if detailResult.reports else None;
        if detail {
            selectedChannel = detail;
            channelPosts = detail.posts or [];
        }
    }
}

impl app.handleLeaveChannel(channelId: str) -> None {
    root spawn leave_channel(channel_id=channelId);
    result = root spawn get_channels();
    channels = result.reports[0] if result.reports else [];
    if selectedChannel and selectedChannel.id == channelId {
        detailResult = root spawn get_channel_detail(channel_id=channelId);
        detail = detailResult.reports[0] if detailResult.reports else None;
        if detail {
            selectedChannel = detail;
            channelPosts = detail.posts or [];
        }
    }
}

impl app.handleSelectChannel(channelId: str) -> None {
    detailResult = root spawn get_channel_detail(channel_id=channelId);
    detail = detailResult.reports[0] if detailResult.reports else None;
    if detail {
        selectedChannel = detail;
        channelPosts = detail.posts or [];
    }
}

impl app.handleChannelPost(text: str) -> None {
    if not text.strip() or not selectedChannel {
        return;
    }
    root spawn create_channel_tweet(channel_id=selectedChannel.id, content=text);
    detailResult = root spawn get_channel_detail(channel_id=selectedChannel.id);
    detail = detailResult.reports[0] if detailResult.reports else None;
    if detail {
        selectedChannel = detail;
        channelPosts = detail.posts or [];
    }
}

impl app.handleBackToChannels -> None {
    selectedChannel = None;
    channelPosts = [];
}
