import from "@jac/runtime" {
    jacIsLoggedIn,
    __getLocalStorage,
    __setLocalStorage,
    BridgeError,
    BridgeUnavailable,
    BridgeTimeout,
    BridgeRejected
}

obj JacYacState {
    has session: Session,
        activeTab: str,
        myProfile: ProfileBundle | None,
        tweets: list[Tweet],
        feedLoading: bool,
        composerText: str,
        searchQuery: str,
        allProfiles: list[Profile],
        avatars: dict[str, str],
        avatarSeen: dict[str, str],
        editingProfile: bool,
        profileSaving: bool,
        profileError: str,
        avatarBusy: bool,
        viewedProfile: ProfileBundle | None,
        viewedLoading: bool,
        trendingTags: list[TrendingTag],
        notifCount: int,
        showWelcome: bool,
        channels: list[ChannelBundle],
        channelsLoading: bool,
        selectedChannel: ChannelBundle | None,
        channelPosts: list[Tweet],
        posting: bool,
        refreshing: bool,
        bridgeMessage: str,
        loadData: Callable[[], None],
        refreshAvatars: Callable[[], None],
        postTweet: Callable[[], None],
        handleLike: Callable[[str], None],
        handleComment: Callable[[str, str], bool],
        handleDelete: Callable[[str], None],
        handleFollow: Callable[[str], None],
        handleUnfollow: Callable[[str], None],
        handleSaveProfile: Callable[[dict[str, str]], None],
        handleClearAvatar: Callable[[], None],
        handleViewProfile: Callable[[str], None],
        handleSearch: Callable[[str], None],
        handleRepost: Callable[[str, str, str], None],
        handleDismissWelcome: Callable[[], None],
        handleTrendClick: Callable[[str], None],
        navigate: Callable[[str], None],
        loadChannels: Callable[[], None],
        handleCreateChannel: Callable[[str, str], None],
        handleJoinChannel: Callable[[str], None],
        handleLeaveChannel: Callable[[str], None],
        handleSelectChannel: Callable[[str], None],
        handleChannelPost: Callable[[str], bool],
        handleBackToChannels: Callable[[], None],
        refreshSocial: Callable[[], None],
        handleRefresh: Callable[[], None],
        handleSaveBio: Callable[[str], None],
        handleAvatarData: Callable[[str], None],
        setActiveTab: Callable[[str], None],
        setComposerText: Callable[[str], None],
        setSearchQuery: Callable[[str], None],
        setEditingProfile: Callable[[bool], None],
        setProfileError: Callable[[str], None],
        logout: Callable[[], None],
        dismissError: Callable[[], None],
        reportError: Callable[[str], None];
}

def:pub useJacYac -> JacYacState;

def bridge_error(error: BridgeError) -> str;

impl bridge_error(error: BridgeError) -> str {
    if isinstance(error, BridgeUnavailable) {
        return "Can’t reach the server. Check your connection and try again.";
    }
    if isinstance(error, BridgeTimeout) {
        return "The server is taking too long to answer.";
    }
    if isinstance(error, BridgeRejected) {
        return "The server refused that request. Please sign in again.";
    }
    return "Something went wrong talking to the server.";
}
