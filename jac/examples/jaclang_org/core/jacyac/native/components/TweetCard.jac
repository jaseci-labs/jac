import from "@jac/mobui" { View, Text, Pressable, TextInput }
import from core.social_graph { Tweet }
import from core.jacyac.native.theme { makeStyles }
import from core.brand.theme { useTheme }
import from core.jacyac.format { handle_of }
import from core.jacyac.native.icon { Icon }
import from .Avatar { Avatar }

def time_ago(stamp: str) -> str {
    if not stamp {
        return "";
    }
    diff_ms = Date.now() - new(Date, stamp).getTime();
    minutes = int(diff_ms / 60000);
    hours = int(minutes / 60);
    days = int(hours / 24);
    if minutes < 1 {
        return "now";
    }
    if hours < 1 {
        return str(minutes) + "m";
    }
    if days < 1 {
        return str(hours) + "h";
    }
    if days < 30 {
        return str(days) + "d";
    }
    return stamp[0:10];
}

def:pub TweetCard(
    avatars: dict[str, str],
    tweet: Tweet,
    myUsername: str,
    onLike: Callable[[str], None],
    onComment: Callable[[str, str], bool],
    onDelete: Callable[[str], None],
) -> JsxElement {
    theme = useTheme();
    C = theme.colors;
    styles = makeStyles(C);
    has showComments: bool = False,
        commentText: str = "",
        confirmDelete: bool = False,
        replying: bool = False;

    async def submitComment {
        text = commentText.strip();
        if not text or replying {
            return;
        }
        replying = True;
        try {
            if await onComment(jid(tweet), text) {
                commentText = "";
            }
        } finally {
            replying = False;
        }
    }

    author = tweet.author_username or "unknown";
    name = handle_of(author);
    is_mine = tweet.author_username != "" and tweet.author_username == myUsername;
    is_liked = myUsername in tweet.likes;
    like_count = len(tweet.likes);
    comment_count = len(tweet.comments);

    <View style={styles.card}>
        <Avatar avatars={avatars} username={author} size={42}/>
        <View style={styles.cardBody}>
            <View style={styles.cardHead}>
                <Text style={styles.name} numberOfLines={1}>{name}</Text>
                <Text style={styles.handle} numberOfLines={1}>{"@" + name}</Text>
                <Text style={styles.handle}>{"· " + time_ago(tweet.created_at)}</Text>
            </View>
            <Text style={styles.cardText}>{tweet.content}</Text>
            <View style={styles.actions}>
                <Pressable
                    accessibilityRole="button"
                    style={styles.action}
                    onPress={lambda { showComments = not showComments; }}
                >
                    <Icon
                        name="comment"
                        size={17}
                        color={C.reply if showComments else C.muted}
                    />
                    {if comment_count > 0 {
                        <Text style={styles.actionCount}>{str(comment_count)}</Text>
                    }}
                </Pressable>
                <Pressable
                    accessibilityRole="button"
                    style={styles.action}
                    onPress={lambda { onLike(jid(tweet)); }}
                >
                    <Icon
                        name="heart"
                        size={17}
                        color={C.like if is_liked else C.muted}
                        fill={is_liked}
                    />
                    {if like_count > 0 {
                        <Text
                            style={styles.actionCountLiked
                                if is_liked
                                else styles.actionCount}
                        >
                            {str(like_count)}
                        </Text>
                    }}
                </Pressable>
                {if is_mine {
                    <Pressable
                        accessibilityRole="button"
                        style={styles.action}
                        onPress={lambda { confirmDelete = not confirmDelete; }}
                    >
                        <Icon name="trash" size={17} color={C.muted}/>
                    </Pressable>
                }}
            </View>
            {if confirmDelete {
                <View style={styles.confirmRow}>
                    <Text style={styles.confirmText}>Delete this post?</Text>
                    <Pressable
                        accessibilityRole="button"
                        style={styles.ghostBtn}
                        onPress={lambda { confirmDelete = False; }}
                    >
                        <Text style={styles.ghostLabel}>Keep</Text>
                    </Pressable>
                    <Pressable
                        accessibilityRole="button"
                        style={styles.dangerBtn}
                        onPress={lambda {
                            confirmDelete = False;
                            onDelete(jid(tweet));
                        }}
                    >
                        <Text style={styles.dangerLabel}>Delete</Text>
                    </Pressable>
                </View>
            }}
            {if showComments {
                <View style={styles.commentList}>
                    {for c in tweet.comments {
                        <View style={styles.commentRow} key={c["created_at"]}>
                            <Avatar
                                avatars={avatars}
                                username={c["username"]}
                                size={26}
                            />
                            <View style={styles.commentBubble}>
                                <Text style={styles.commentName}>
                                    {handle_of(c["username"])}
                                </Text>
                                <Text style={styles.commentText}>{c["content"]}</Text>
                            </View>
                        </View>
                    }}
                    <View style={styles.commentComposer}>
                        <TextInput
                            style={styles.commentInput}
                            value={commentText}
                            placeholder="Post your reply"
                            placeholderTextColor={C.muted}
                            returnKeyType="send"
                            onChangeText={lambda (t: str) { commentText = t; }}
                            onSubmitEditing={lambda { submitComment(); }}
                        />
                        <Pressable
                            accessibilityRole="button"
                            style={[
                                styles.sendBtn,
                                (
                                    styles.btnDisabled
                                        if not commentText.strip()
                                        else None
                                )
                            ]}
                            disabled={not commentText.strip()}
                            onPress={lambda { submitComment(); }}
                        >
                            <Icon name="send" size={16} color={C.accentText}/>
                        </Pressable>
                    </View>
                </View>
            }}
        </View>
    </View>
}
