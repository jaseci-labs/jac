import from core.jacyac.validation { valid_post }
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
import from core.jacyac.identity { project_error_message }

import from .session { Session, useSession, stored_username }
import from "@jac/runtime" {
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
        exploreMode: str,
        allProjects: list[Project],
        projectsLoading: bool,
        projectBusy: bool,
        projectError: str,
        projectNotice: str,
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
        loadProjects: Callable[[], None],
        handleAddProject: Callable[[str], bool],
        handleRemoveProject: Callable[[str], None],
        handleRescoreProject: Callable[[str], None],
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
        setExploreMode: Callable[[str], None],
        logout: Callable[[], None],
        dismissError: Callable[[], None],
        reportError: Callable[[str], None];
}

def:pub useJacYac -> JacYacState {
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
    async def loadProjects -> None;
    async def handleAddProject(url: str) -> bool;
    async def handleRemoveProject(projectId: str) -> None;
    async def handleRescoreProject(projectId: str) -> None;
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
        exploreMode = "people";
        allProjects = [];
        projectsLoading = False;
        projectBusy = False;
        projectError = "";
        projectNotice = "";
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
        exploreMode=exploreMode,
        allProjects=allProjects,
        projectsLoading=projectsLoading,
        projectBusy=projectBusy,
        projectError=projectError,
        projectNotice=projectNotice,
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
        loadProjects=loadProjects,
        handleAddProject=handleAddProject,
        handleRemoveProject=handleRemoveProject,
        handleRescoreProject=handleRescoreProject,
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
        setExploreMode=lambda (value: str) { exploreMode = value; },
        logout=logout,
        dismissError=lambda { bridgeMessage = ""; },
        reportError=lambda (message: str) { bridgeMessage = message; }
    );
}

def bridge_error(error: BridgeError) -> str {
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
