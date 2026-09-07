import from "@jac/mobui" { View, Text, Pressable, TextInput, ScrollView }
import from core.social_graph { ProfileBundle }
import from core.jacyac.native.theme { makeStyles }
import from core.brand.theme { useTheme }
import from core.jacyac.identity { name_of }
import from core.jacyac.format { handle_of }
import from core.jacyac.native.icon { Icon }
import from core.jacyac.native.components.Avatar { Avatar }
import from core.jacyac.native.components.TweetCard { TweetCard }
import from core.jacyac.native.components.StatusView { EmptyState }

def:pub ProfileScreen(
    avatars: dict[str, str],
    profile: ProfileBundle | None,
    editing: bool,
    saving: bool,
    error: str,
    bioText: str,
    onBioChange: Callable[[str], None],
    onSaveBio: Callable[[], None],
    onStartEdit: Callable[[], None],
    onCancelEdit: Callable[[], None],
    onLogout: Callable[[], None],
    onLike: Callable[[str], None],
    onComment: Callable[[str, str], None],
    onDelete: Callable[[str], None],
) -> JsxElement {
    theme = useTheme();
    C = theme.colors;
    styles = makeStyles(C);
    username = profile.profile.username if profile else "";
    name = name_of(profile.profile.display_name, profile.profile.username)
        if profile
        else "";
    bio = profile.profile.bio if profile else "";
    followers = len(profile.followers) if profile else 0;
    following = len(profile.following) if profile else 0;
    my_tweets = profile.tweets if profile else [];
    post_count = len(my_tweets);

    <ScrollView
        style={styles.body}
        contentContainerStyle={styles.scrollBody}
        keyboardShouldPersistTaps="handled"
    >
        <View style={styles.profileHero}/>
        <View style={styles.profileHead}>
            <View style={styles.profileTopRow}>
                <Avatar avatars={avatars} username={username} size={76}/>
                <View style={styles.rowGap}>
                    {if not editing {
                        <Pressable
                            accessibilityRole="button"
                            style={styles.outlineBtn}
                            onPress={lambda { onStartEdit(); }}
                        >
                            <Icon name="edit" size={14} color={C.text}/>
                            <Text style={styles.outlineLabel}>Edit</Text>
                        </Pressable>
                    }}
                    <Pressable
                        accessibilityRole="button"
                        style={styles.outlineBtn}
                        onPress={lambda { onLogout(); }}
                    >
                        <Icon name="logout" size={14} color={C.text}/>
                        <Text style={styles.outlineLabel}>Log out</Text>
                    </Pressable>
                </View>
            </View>
            <Text style={styles.profileName}>{name or "Setting up..."}</Text>
            <Text style={styles.profileHandle}>{"@" + handle_of(username)}</Text>
            {if error {
                <Text style={styles.errorText}>{error}</Text>
            }}
            {if editing {
                <View style={styles.editBox}>
                    <TextInput
                        style={styles.bioInput}
                        value={bioText}
                        placeholder="Write your bio"
                        placeholderTextColor={C.muted}
                        multiline={True}
                        onChangeText={onBioChange}
                    />
                    <View style={styles.rowGap}>
                        <Pressable
                            accessibilityRole="button"
                            style={styles.pillBtn}
                            disabled={saving}
                            onPress={lambda { onSaveBio(); }}
                        >
                            <Text style={styles.primaryLabel}>
                                {"Saving…" if saving else "Save"}
                            </Text>
                        </Pressable>
                        <Pressable
                            accessibilityRole="button"
                            style={styles.ghostBtn}
                            onPress={lambda { onCancelEdit(); }}
                        >
                            <Text style={styles.ghostLabel}>Cancel</Text>
                        </Pressable>
                    </View>
                </View>
            } else {
                <Text style={styles.profileBio}>{bio or "No bio yet"}</Text>
            } }
            <View style={styles.statsRow}>
                <Text style={styles.stat}>
                    <Text style={styles.statNum}>{str(following)}</Text>
                    {" Following"}
                </Text>
                <Text style={styles.stat}>
                    <Text style={styles.statNum}>{str(followers)}</Text>
                    {" " + ("Follower" if followers == 1 else "Followers")}
                </Text>
                <Text style={styles.stat}>
                    <Text style={styles.statNum}>{str(post_count)}</Text>
                    {" " + ("Post" if post_count == 1 else "Posts")}
                </Text>
            </View>
        </View>
        {if post_count == 0 {
            <EmptyState
                icon="feather"
                title="No posts yet"
                hint="Everything you post shows up here."
            />
        } else {
            for tweet in my_tweets {
                <TweetCard
                    avatars={avatars}
                    key={jid(tweet)}
                    tweet={tweet}
                    myUsername={username}
                    onLike={onLike}
                    onComment={onComment}
                    onDelete={onDelete}
                />
            }
        } }
    </ScrollView>
}
