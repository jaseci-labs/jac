import from "@jac/mobui" { View, Text, Pressable, ScrollView }
import from core.social_graph { Profile, TrendingTag }
import from core.jacyac.native.theme { makeStyles }
import from core.brand.theme { useTheme }
import from core.jacyac.identity { name_of }
import from core.jacyac.format { handle_of }
import from core.jacyac.native.icon { Icon }
import from core.jacyac.native.components.Avatar { Avatar }
import from core.jacyac.native.components.StatusView { EmptyState, LoadingRows }

def:pub ExploreScreen(
    avatars: dict[str, str],
    profiles: list[Profile],
    followingIds: list[str],
    myProfileId: str,
    trending: list[TrendingTag],
    loading: bool,
    onFollow: Callable[[str], None],
    onUnfollow: Callable[[str], None],
    onTrendPress: Callable[[str], None],
) -> JsxElement {
    theme = useTheme();
    C = theme.colors;
    styles = makeStyles(C);
    others = [
        u
        for u in profiles
        if jid(u) != myProfileId
    ];

    <ScrollView style={styles.body} contentContainerStyle={styles.scrollBody}>
        <Text style={styles.sectionLabel}>Trending</Text>
        {if len(trending) == 0 {
            <Text style={styles.sectionHint}>
                Hashtags people use in their posts show up here.
            </Text>
        } else {
            <View style={styles.chipRow}>
                {for tag in trending {
                    <Pressable
                        accessibilityRole="button"
                        style={styles.chip}
                        key={tag.tag}
                        onPress={lambda { onTrendPress(tag.tag); }}
                    >
                        <Icon name="trending" size={14} color={C.accent}/>
                        <Text style={styles.chipText}>{tag.tag}</Text>
                        <Text style={styles.chipCount}>{str(tag.count)}</Text>
                    </Pressable>
                }}
            </View>
        } }
        <Text style={styles.sectionLabel}>People</Text>
        {if loading and len(others) == 0 {
            <LoadingRows count={4}/>
        } elif len(others) == 0 {
            <EmptyState
                icon="users"
                title="No one to show"
                hint="Ask a friend to sign up and they will appear here."
            />
        } else {
            for u in others {
                <View style={styles.personRow} key={jid(u)}>
                    <Avatar avatars={avatars} username={u.username} size={44}/>
                    <View style={styles.personBody}>
                        <Text style={styles.name} numberOfLines={1}>
                            {name_of(u.display_name, u.username)}
                        </Text>
                        <Text style={styles.handle} numberOfLines={1}>
                            {"@" + handle_of(u.username)}
                        </Text>
                        <Text style={styles.personBio} numberOfLines={2}>
                            {u.bio or "No bio yet"}
                        </Text>
                    </View>
                    {if jid(u) in followingIds {
                        <Pressable
                            accessibilityRole="button"
                            style={styles.outlineBtn}
                            onPress={lambda { onUnfollow(jid(u)); }}
                        >
                            <Icon name="check" size={14} color={C.text}/>
                            <Text style={styles.outlineLabel}>Following</Text>
                        </Pressable>
                    } else {
                        <Pressable
                            accessibilityRole="button"
                            style={styles.pillBtn}
                            onPress={lambda { onFollow(jid(u)); }}
                        >
                            <Text style={styles.primaryLabel}>Follow</Text>
                        </Pressable>
                    } }
                </View>
            }
        }  }
    </ScrollView>
}
