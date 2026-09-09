import from core.brand.font { useBrandFont }
import from core.jacyac.native.components.BrandMark { BrandMark }
import from "@jac/mobui" {
    View,
    Text,
    StatusBar,
    ActivityIndicator,
    Pressable,
    useWindowDimensions
}
import from core.jacyac.state { useJacYac }
import from core.jacyac.native.theme { makeStyles }
import from core.brand.theme { useTheme }
import from .icon { Icon }
import from .components.TabBar { TabBar }
import from .components.BridgeBanner { BridgeBanner }
import from .screens.AuthScreen { AuthScreen }
import from .screens.ScoresScreen { ScoresScreen }
import from .screens.FeedScreen { FeedScreen }
import from .screens.ExploreScreen { ExploreScreen }
import from .screens.ChannelsScreen { ChannelsScreen }
import from .screens.ProfileScreen { ProfileScreen }

glob TAB_TITLES: dict[str, str] = {
         "feed": "Home",
         "scores": "Ninja Scores",
         "explore": "Explore",
         "channels": "Channels",
         "profile": "Profile"
     };

def:pub JacYacMobile(embedded: bool = False) -> JsxElement {
    theme = useTheme();
    C = theme.colors;
    styles = makeStyles(C);
    model = useJacYac();
    fontReady = useBrandFont();
    has bioText: str = "";
    viewport = useWindowDimensions();
    async def navigate(tab: str) {
        await model.navigate(tab);
    }
    async def handleSearch {
        await model.handleSearch(model.searchQuery);
    }
    async def clearSearch {
        await model.handleSearch("");
    }
    async def handleTrendPress(tag: str) {
        model.setActiveTab("feed");
        await model.handleSearch(tag);
    }
    def startEditBio {
        bioText = model.myProfile.profile.bio if model.myProfile else "";
        model.setEditingProfile(True);
        model.setProfileError("");
    }
    async def handleSaveBio {
        await model.handleSaveBio(bioText);
    }
    if model.session.checking {
        return
            <View style={styles.center}>
                <ActivityIndicator size="large" color={C.accent}/>
            </View>;
    }

    if not model.session.loggedIn and model.activeTab != "scores" {
        return
            <AuthScreen
                embedded={embedded}
                onScores={lambda { model.navigate("scores"); }}
                isSignup={model.session.signup}
                username={model.session.username}
                password={model.session.password}
                error={model.session.error}
                loading={model.session.busy}
                onUsernameChange={lambda (t: str) { model.session.setUsername(t); }}
                onPasswordChange={lambda (t: str) { model.session.setPassword(t); }}
                onSubmit={model.session.submit}
                onToggleMode={model.session.toggleMode}
                githubEnabled={model.session.githubEnabled}
                onGithub={model.session.githubLogin}
            />;
    }

    profileUsername = model.myProfile.profile.username if model.myProfile else "";
    myProfileId = jid(model.myProfile.profile) if model.myProfile else "";
    followingIds = [
        jid(f) for f in (model.myProfile.following if model.myProfile else [])
    ];

    <View
        testID="jacyac-native"
        style={[
            styles.root,
            {
                "height": "100%" if embedded else viewport.height,
                "paddingTop": 24 if embedded else 0
            }
        ]}
    >
        <StatusBar
            barStyle={"light-content" if theme.dark else "dark-content"}
            backgroundColor={C.bg}
        />
        <View style={styles.page}>
            <View style={styles.header}>
                <View style={styles.headerBrand}>
                    <View style={styles.rowGap}>
                        <BrandMark size={40}/>
                    </View>
                    <Text style={styles.headerTitle}>JacYac</Text>
                </View>
                <Text style={styles.headerHandle} numberOfLines={1}>
                    {TAB_TITLES[model.activeTab]}
                </Text>
            </View>
            {if model.bridgeMessage {
                <BridgeBanner
                    message={model.bridgeMessage}
                    canRetry={True}
                    onRetry={model.handleRefresh}
                    onDismiss={model.dismissError}
                />
            }}
            <View style={styles.body}>
                {if model.activeTab == "scores" {
                    <ScoresScreen model={model}/>
                } elif model.activeTab == "feed" {
                    <FeedScreen
                        avatars={model.avatars}
                        username={profileUsername}
                        composerText={model.composerText}
                        onComposerChange={lambda (t: str) { model.setComposerText(t); }}
                        onPost={model.postTweet}
                        posting={model.posting}
                        searchQuery={model.searchQuery}
                        onSearchChange={lambda (t: str) { model.setSearchQuery(t); }}
                        onSearch={handleSearch}
                        onClearSearch={clearSearch}
                        loading={model.feedLoading}
                        refreshing={model.refreshing}
                        onRefresh={model.handleRefresh}
                        tweets={model.tweets}
                        onLike={model.handleLike}
                        onComment={model.handleComment}
                        onDelete={model.handleDelete}
                    />
                } elif model.activeTab == "explore" {
                    <ExploreScreen
                        avatars={model.avatars}
                        profiles={model.allProfiles}
                        followingIds={followingIds}
                        myProfileId={myProfileId}
                        trending={model.trendingTags}
                        loading={model.feedLoading}
                        onFollow={model.handleFollow}
                        onUnfollow={model.handleUnfollow}
                        onTrendPress={handleTrendPress}
                    />
                } elif model.activeTab == "channels" {
                    <ChannelsScreen
                        avatars={model.avatars}
                        channels={model.channels}
                        loading={model.channelsLoading}
                        selected={model.selectedChannel}
                        posts={model.channelPosts}
                        username={profileUsername}
                        onCreate={model.handleCreateChannel}
                        onJoin={model.handleJoinChannel}
                        onLeave={model.handleLeaveChannel}
                        onSelect={model.handleSelectChannel}
                        onBack={model.handleBackToChannels}
                        onPost={model.handleChannelPost}
                        onLike={model.handleLike}
                        onComment={model.handleComment}
                        onDelete={model.handleDelete}
                    />
                } else {
                    <ProfileScreen
                        avatars={model.avatars}
                        profile={model.myProfile}
                        editing={model.editingProfile}
                        bioText={bioText}
                        onBioChange={lambda (t: str) { bioText = t; }}
                        saving={model.profileSaving}
                        error={model.profileError}
                        onSaveBio={handleSaveBio}
                        onStartEdit={startEditBio}
                        onCancelEdit={lambda { model.setEditingProfile(False); }}
                        onLogout={model.logout}
                        onLike={model.handleLike}
                        onComment={model.handleComment}
                        onDelete={model.handleDelete}
                    />
                }    }
            </View>
            <Pressable
                accessibilityRole="button"
                accessibilityLabel="Toggle theme"
                onPress={theme.toggle}
            >
                <Text style={styles.footnote}>
                    {"Light appearance" if theme.dark else "Dark appearance"}
                </Text>
            </Pressable>
            <TabBar activeTab={model.activeTab} onNavigate={navigate}/>
        </View>
    </View>
}
