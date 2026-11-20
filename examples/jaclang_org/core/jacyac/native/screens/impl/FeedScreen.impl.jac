impl FeedScreen(
    avatars: dict[str, str],
    username: str,
    composerText: str,
    onComposerChange: Callable[[str], None],
    onPost: Callable[[], Coroutine[any, any, None]],
    posting: bool,
    searchQuery: str,
    onSearchChange: Callable[[str], None],
    onSearch: Callable[[], Coroutine[any, any, None]],
    onClearSearch: Callable[[], Coroutine[any, any, None]],
    loading: bool,
    refreshing: bool,
    onRefresh: Callable[[], Coroutine[any, any, None]],
    tweets: list[Tweet],
    onLike: Callable[[str], Coroutine[any, any, None]],
    onComment: Callable[[str, str], Coroutine[any, any, bool]],
    onDelete: Callable[[str], Coroutine[any, any, None]],
) -> JsxElement {
    theme = useTheme();
    C = theme.colors;
    styles = makeStyles(C);
    return <ScrollView
        style={styles.body}
        contentContainerStyle={styles.scrollBody}
        keyboardShouldPersistTaps="handled"
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={lambda { onRefresh() }} tintColor={C.accent} colors={[C.accent]} />}
    >
        <View style={styles.searchBar}>
            <Icon name="search" size={17} color={C.muted} />
            <TextInput
                style={styles.searchInput}
                value={searchQuery}
                placeholder="Search posts"
                placeholderTextColor={C.muted}
                autoCapitalize="none"
                returnKeyType="search"
                onChangeText={onSearchChange}
                onSubmitEditing={lambda { onSearch() }}
            />
            {
                if searchQuery {
                    <Pressable accessibilityRole="button" onPress={lambda { onClearSearch() }}>
                        <Icon name="close" size={16} color={C.muted} />
                    </Pressable>
                }
            }
        </View>
        <Composer
            avatars={avatars}
            username={username}
            placeholder="What's happening?"
            value={composerText}
            onChange={onComposerChange}
            onPost={onPost}
            busy={posting}
        />
        {
            if loading {
                <LoadingRows count={4} />
            } elif len(tweets) == 0 {
                <EmptyState
                    icon="inbox"
                    title={"No matches" if searchQuery else "Nothing here yet"}
                    hint={"Try another word or clear the search." if searchQuery else "Follow people or post something to fill your feed."}
                />
            } else {
                for tweet in tweets {
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
            }
        }
    </ScrollView>;
}
