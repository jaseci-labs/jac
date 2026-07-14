import datetime;


# ─────────────────────────────────────────────────────────────────────────────
#  BACKEND  —  persisted graph + walkers (the API)
# ─────────────────────────────────────────────────────────────────────────────
node Tweet {
    has content: str,
        author: str,
        likes: int = 0,
        retweets: int = 0,
        comments: int = 0,
        created_at: str = datetime.datetime.now().strftime("%H:%M");
}


node Comment {
    has content: str,
        author: str,
        created_at: str = datetime.datetime.now().strftime("%H:%M");
}


"""Sample posts so a fresh graph isn't empty (different authors)."""
glob SEED_TWEETS = [
         {
             "author": "ada",
             "content": "one .jac file, web and native. the whole feed persists on the graph."
         },
         {
             "author": "grace",
             "content": "debugging is twice as hard as writing the code — good thing the backend lives right next to the UI."
         },
         {
             "author": "linus",
             "content": "talk is cheap. show me the walkers. (they're the API here.)"
         },
         {
             "author": "margaret",
             "content": "shipped to the browser and the app store from the same source. no platform fork."
         },
         {
             "author": "alan",
             "content": "the icons are real Lucide vectors — lucide-react on web, lucide-react-native on native."
         }
     ];


"""Read the whole feed (public shared timeline)."""
walker:pub load_feed {
    can go with Root entry {
        visit [-->[?:Tweet]];
    }

    can collect with Tweet entry {
        report here;
    }
}


"""Seed the feed with sample posts on first run, then return it. Idempotent —
only seeds when the graph has no tweets yet."""
walker:pub seed_feed {
    can run with Root entry {
        if not [-->[?:Tweet]] {
            for s in SEED_TWEETS {
                here ++> Tweet(content=s["content"], author=s["author"]);
            }
        }
        visit [-->[?:Tweet]];
    }

    can collect with Tweet entry {
        report here;
    }
}


"""Create a tweet on the shared root graph."""
walker:pub create_tweet {
    has content: str,
        author: str;

    can make with Root entry {
        new_tweet = here ++> Tweet(content=self.content, author=self.author);
        report new_tweet;
    }
}


"""Like a single tweet — spawned on a node id (`tid spawn like_tweet()`)."""
walker:pub like_tweet {
    can do with Tweet entry {
        here.likes += 1;
        report here;
    }
}


"""Un-like a tweet (toggle off)."""
walker:pub unlike_tweet {
    can do with Tweet entry {
        if here.likes > 0 {
            here.likes -= 1;
        }
        report here;
    }
}


"""Retweet (share) a single tweet — spawned on a node id."""
walker:pub retweet_tweet {
    can do with Tweet entry {
        here.retweets += 1;
        report here;
    }
}


"""Un-retweet a tweet (toggle off)."""
walker:pub unretweet_tweet {
    can do with Tweet entry {
        if here.retweets > 0 {
            here.retweets -= 1;
        }
        report here;
    }
}


"""Add a comment to a tweet — spawned on the tweet's node id."""
walker:pub add_comment {
    has content: str,
        author: str;

    can do with Tweet entry {
        here ++> Comment(content=self.content, author=self.author);
        here.comments += 1;
        report here;
    }
}


"""Read all comments on a tweet — spawned on the tweet's node id."""
walker:pub load_comments {
    can go with Tweet entry {
        visit [-->[?:Comment]];
    }

    can collect with Comment entry {
        report here;
    }
}


# ─────────────────────────────────────────────────────────────────────────────
#  CLIENT  —  one cross-platform app, @jac/mobui primitives + Lucide icons
# ─────────────────────────────────────────────────────────────────────────────
cl {
    import from "@jac/mobui" {
        View,
        Text,
        Pressable,
        TextInput,
        Image,
        ScrollView,
        Animated,
        Easing,
        createAnimatedValue,
        useWindowDimensions
    }
    # Real Lucide icons. The compiler resolves icon.cl.jac on web (lucide-react)
    # and icon.native.cl.jac on native (lucide-react-native) — same <Icon/> API.
    import from .icon { Icon }
    import from .theme { C, S, R, F, styles }

    glob intro = createAnimatedValue(0);

    def avatarFor(seed: str) -> str {
        return f"https://api.dicebear.com/7.x/thumbs/png?seed={seed}";
    }

    # ── Reusable presentational components (no state) ─────────────────────────
    # (Icon is imported from ./icon.cl.jac — Lucide on web, lucide-react-native
    #  on native — see the import at the top of this cl block.)
    def Avatar(seed: str, size: int) -> JsxElement {
        return
            <Image
                source={{uri: avatarFor(seed)}}
                style={[styles.avatar, {width: size, height: size}]}
            />;
    }

    def:pub app -> JsxElement {
        has screen: str = "splash",
            authMode: str = "login",
            authUser: str = "",
            authPass: str = "",
            authPass2: str = "",
            authError: str = "",
            me: str = "",
            tab: str = "home",
            profileUser: str = "",
            tweets: list = [],
            liked: list = [],
            retweeted: list = [],
            draft: str = "",
            query: str = "",
            # comment modal state
            commentTid: any = None,
            commentList: list = [],
            commentDraft: str = "";

        # live viewport — gives the root an explicit height so the dark app
        # fills the screen on web (otherwise #root collapses to content height).
        viewport = useWindowDimensions();

        async can with entry {
            result = root spawn seed_feed();
            tweets = result.reports;
            Animated.timing(
                intro,
                {
                    toValue: 1,
                    duration: 500,
                    easing: Easing.out(Easing.cubic),
                    useNativeDriver: True
                }
            ).start();
            setTimeout(lambda { if screen == "splash" { screen = "auth"; }}, 1500);
        }

        def newestFirst(xs: list) -> list {
            r = [];
            for x in xs {
                r = [x] + r;
            }
            return r;
        }

        async def reload {
            result = root spawn load_feed();
            tweets = result.reports;
        }

        def submitAuth -> None {
            authError = "";
            if len(authUser.strip()) < 3 {
                authError = "Username must be at least 3 characters.";
                return;
            }
            if len(authPass) < 6 {
                authError = "Password must be at least 6 characters.";
                return;
            }
            if authMode == "signup" and authPass != authPass2 {
                authError = "Passwords do not match.";
                return;
            }
            me = authUser.strip();
            authPass = "";
            authPass2 = "";
            tab = "home";
            screen = "app";
        }

        def logout {
            me = "";
            authUser = "";
            screen = "auth";
            authMode = "login";
        }

        async def post -> None {
            txt = draft.strip();
            if not txt {
                return;
            }
            root spawn create_tweet(content=txt, author=me);
            draft = "";
            reload();
        }

        async def likeTweet(tid: any) {
            if tid in liked {
                result = tid spawn unlike_tweet();
                updated = result.reports[0];
                tweets = [updated if x._jac_id == tid else x for x in tweets];
                liked = [
                    x
                    for x in liked
                    if x != tid
                ];
            } else {
                result = tid spawn like_tweet();
                updated = result.reports[0];
                tweets = [updated if x._jac_id == tid else x for x in tweets];
                liked = liked + [tid];
            }
        }

        async def retweetTweet(tid: any) {
            if tid in retweeted {
                result = tid spawn unretweet_tweet();
                updated = result.reports[0];
                tweets = [updated if x._jac_id == tid else x for x in tweets];
                retweeted = [
                    x
                    for x in retweeted
                    if x != tid
                ];
            } else {
                result = tid spawn retweet_tweet();
                updated = result.reports[0];
                tweets = [updated if x._jac_id == tid else x for x in tweets];
                retweeted = retweeted + [tid];
            }
        }

        async def openComments(tid: any) {
            commentTid = tid;
            commentDraft = "";
            commentList = [];
            result = tid spawn load_comments();
            commentList = result.reports;
        }

        def closeComments {
            commentTid = None;
            commentList = [];
            commentDraft = "";
        }

        async def submitComment -> None {
            txt = commentDraft.strip();
            if not txt or commentTid == None {
                return;
            }
            result = commentTid spawn add_comment(content=txt, author=me);
            updated = result.reports[0];
            tweets = [updated if x._jac_id == commentTid else x for x in tweets];
            commentDraft = "";
            # refresh the comment list for the open thread
            refreshed = commentTid spawn load_comments();
            commentList = refreshed.reports;
        }

        def openProfile(u: str) {
            profileUser = u;
            tab = "profile";
        }

        # ── tweet card — a component (invoke as <TweetCard t={..}/>) so props
        #    are passed correctly; it still closes over state (likeTweet, etc.) ─
        def TweetCard(t: any) -> JsxElement {
            return
                <View style={styles.card} key={t._jac_id}>
                    <Pressable onPress={lambda { openProfile(t.author); }}>
                        <Avatar seed={t.author} size={44}/>
                    </Pressable>
                    <View style={styles.cardBody}>
                        <View style={styles.cardHead}>
                            <Pressable onPress={lambda { openProfile(t.author); }}>
                                <Text style={styles.name}>{t.author}</Text>
                            </Pressable>
                            <Text style={styles.handle}>
                                @{t.author} · {t.created_at}
                            </Text>
                        </View>
                        <Text style={styles.cardText}>{t.content}</Text>
                        <View style={styles.actions}>
                            <Pressable
                                style={styles.action}
                                onPress={lambda { likeTweet(t._jac_id); }}
                            >
                                <Icon
                                    name="heart"
                                    size={18}
                                    color={(
                                        C.like if (t._jac_id in liked) else C.muted
                                    )}
                                    fill={(t._jac_id in liked)}
                                    width={2}
                                />
                                <Text
                                    style={(
                                        styles.actionCountLiked
                                            if (t._jac_id in liked)
                                            else styles.actionCount
                                    )}
                                >
                                    {t.likes}
                                </Text>
                            </Pressable>
                            <Pressable
                                style={styles.action}
                                onPress={lambda { openComments(t._jac_id); }}
                            >
                                <Icon
                                    name="comment"
                                    size={18}
                                    color={C.muted}
                                    fill={False}
                                    width={2}
                                />
                                <Text style={styles.actionCount}>{t.comments}</Text>
                            </Pressable>
                            <Pressable
                                style={styles.action}
                                onPress={lambda { retweetTweet(t._jac_id); }}
                            >
                                <Icon
                                    name="repeat"
                                    size={18}
                                    color={(
                                        C.rt if (t._jac_id in retweeted) else C.muted
                                    )}
                                    fill={False}
                                    width={2}
                                />
                                <Text
                                    style={(
                                        styles.actionCountRt
                                            if (t._jac_id in retweeted)
                                            else styles.actionCount
                                    )}
                                >
                                    {t.retweets}
                                </Text>
                            </Pressable>
                        </View>
                    </View>
                </View>;
        }

        # ── screens ───────────────────────────────────────────────────────────
        def renderHome -> JsxElement {
            ordered = newestFirst(tweets);
            return
                <ScrollView style={styles.body}>
                    <View style={styles.composer}>
                        <Avatar seed={me} size={44}/>
                        <View style={styles.composerCol}>
                            <TextInput
                                style={styles.composerInput}
                                value={draft}
                                placeholder="What's happening?"
                                placeholderTextColor={C.muted}
                                multiline={True}
                                onChangeText={lambda (v: str) { draft = v; }}
                            />
                            <View style={styles.composerActions}>
                                <Icon
                                    name="image"
                                    size={20}
                                    color={C.accent}
                                    fill={False}
                                    width={2}
                                />
                                <Pressable style={styles.primaryBtn} onPress={post}>
                                    <View
                                        style={{
                                            flexDirection: "row",
                                            alignItems: "center",
                                            gap: S.xs,
                                            paddingHorizontal: S.sm
                                        }}
                                    >
                                        <Icon
                                            name="edit"
                                            size={16}
                                            color={C.accentText}
                                            fill={False}
                                            width={2}
                                        />
                                        <Text style={styles.primaryLabel}>Post</Text>
                                    </View>
                                </Pressable>
                            </View>
                        </View>
                    </View>
                    {(
                        <View style={styles.empty}>
                            <Text style={styles.emptyTitle}>No posts yet</Text>
                            <Text style={styles.emptyText}>
                                Be the first to post — it persists on the graph.
                            </Text>
                        </View>
                    )
                        if (len(ordered) == 0)
                        else (
                            <View>
                                {[<TweetCard key={t._jac_id} t={t}/> for t in ordered]}
                            </View>
                        )}
                </ScrollView>;
        }

        def renderSearch -> JsxElement {
            results = [
                t
                for t in newestFirst(tweets)
                if query != "" and (query in t.content or query in t.author)
            ];
            return
                <View style={styles.body}>
                    <View style={styles.searchBar}>
                        <Icon
                            name="search"
                            size={18}
                            color={C.muted}
                            fill={False}
                            width={2}
                        />
                        <TextInput
                            style={styles.searchInput}
                            value={query}
                            placeholder="Search posts and people"
                            placeholderTextColor={C.muted}
                            onChangeText={lambda (v: str) { query = v; }}
                        />
                    </View>
                    <ScrollView style={styles.body}>
                        {(
                            <View style={styles.empty}>
                                <Icon
                                    name="search"
                                    size={32}
                                    color={C.muted}
                                    fill={False}
                                    width={1.6}
                                />
                                <Text style={styles.emptyTitle}>Search LittleX</Text>
                                <Text style={styles.emptyText}>
                                    Find posts by keyword or author name.
                                </Text>
                            </View>
                        )
                            if (query == "")
                            else (
                                (
                                    <View style={styles.empty}>
                                        <Text style={styles.emptyTitle}>
                                            No results
                                        </Text>
                                        <Text style={styles.emptyText}>
                                            Nothing matched "{query}".
                                        </Text>
                                    </View>
                                )
                                    if (len(results) == 0)
                                    else (
                                        <View>
                                            {[
                                                <TweetCard key={t._jac_id} t={t}/>
                                                for t in results
                                            ]}
                                        </View>
                                    )
                            )}
                    </ScrollView>
                </View>;
        }

        def renderNotifications -> JsxElement {
            notes = [
                t
                for t in newestFirst(tweets)
                if t.author == me and t.likes > 0
            ];
            return
                <ScrollView style={styles.body}>
                    <Text style={styles.sectionLabel}>NOTIFICATIONS</Text>
                    {(
                        <View style={styles.empty}>
                            <Icon
                                name="bell"
                                size={32}
                                color={C.muted}
                                fill={False}
                                width={1.6}
                            />
                            <Text style={styles.emptyTitle}>Nothing yet</Text>
                            <Text style={styles.emptyText}>
                                Likes on your posts will show up here.
                            </Text>
                        </View>
                    )
                        if (len(notes) == 0)
                        else (
                            <View>
                                {[
                                    <View style={styles.noteRow} key={n._jac_id}>
                                        <View style={styles.noteIcon}>
                                            <Icon
                                                name="heart"
                                                size={18}
                                                color={C.like}
                                                fill={True}
                                                width={2}
                                            />
                                        </View>
                                        <View style={styles.noteBody}>
                                            <Text style={styles.noteText}>
                                                Your post earned {n.likes} likes
                                            </Text>
                                            <Text style={styles.noteSnippet}>
                                                {n.content}
                                            </Text>
                                        </View>
                                    </View> for n in notes
                                ]}
                            </View>
                        )}
                </ScrollView>;
        }

        def renderProfile -> JsxElement {
            who = profileUser if profileUser != "" else me;
            mine = [
                t
                for t in tweets
                if t.author == who
            ];
            posts = len(mine);
            total = 0;
            for t in mine {
                total += t.likes;
            }
            isMe = who == me;
            return
                <ScrollView style={styles.body}>
                    <View style={styles.profileHead}>
                        <View style={styles.profileTopRow}>
                            <Avatar seed={who} size={72}/>
                            {(
                                <Pressable style={styles.outlineBtn} onPress={logout}>
                                    <Icon
                                        name="logout"
                                        size={15}
                                        color={C.text}
                                        fill={False}
                                        width={2}
                                    />
                                    <Text style={styles.outlineLabel}>Log out</Text>
                                </Pressable>
                            )
                                if isMe
                                else (
                                    <Pressable style={styles.outlineBtn}>
                                        <Text style={styles.outlineLabel}>Follow</Text>
                                    </Pressable>
                                )}
                        </View>
                        <View style={{gap: S.xs}}>
                            <Text style={styles.profileName}>{who}</Text>
                            <Text style={styles.profileHandle}>@{who}</Text>
                        </View>
                        <Text style={styles.profileBio}>
                            Building cross-platform apps with Jac — one codebase, web and native.
                        </Text>
                        <View style={styles.profileMetaRow}>
                            <Icon
                                name="calendar"
                                size={15}
                                color={C.muted}
                                fill={False}
                                width={2}
                            />
                            <Text style={styles.statMuted}>Joined LittleX</Text>
                        </View>
                        <View style={styles.statsRow}>
                            <Text style={styles.statText}>
                                {posts}{" "}
                                <Text style={styles.statMuted}>Posts</Text>
                            </Text>
                            <Text style={styles.statText}>
                                {total}{" "}
                                <Text style={styles.statMuted}>Likes</Text>
                            </Text>
                        </View>
                    </View>
                    {(
                        <View style={styles.empty}>
                            <Text style={styles.emptyTitle}>No posts yet</Text>
                        </View>
                    )
                        if (len(mine) == 0)
                        else (
                            <View>
                                {[
                                    <TweetCard key={t._jac_id} t={t}/>
                                    for t in newestFirst(mine)
                                ]}
                            </View>
                        )}
                </ScrollView>;
        }

        def TabButton(tabKey: str, icon: str) -> JsxElement {
            active = tab == tabKey;
            return
                <Pressable
                    style={styles.tabItem}
                    onPress={lambda {
                        tab = tabKey;
                        if tabKey == "profile" {
                            profileUser = me;
                        }
                    }}
                >
                    <Icon
                        name={icon}
                        size={24}
                        color={(C.text if active else C.muted)}
                        fill={active}
                        width={2}
                    />
                </Pressable>;
        }

        def renderApp -> JsxElement {
            return
                <View style={styles.page}>
                    <View style={styles.header}>
                        <View style={styles.headerBrand}>
                            <View style={styles.headerLogo}>
                                <Icon
                                    name="spark"
                                    size={18}
                                    color={C.accentText}
                                    fill={True}
                                    width={2}
                                />
                            </View>
                            <Text style={styles.headerTitle}>LittleX</Text>
                        </View>
                        <Pressable
                            style={styles.avatarBtn}
                            onPress={lambda { openProfile(me); }}
                        >
                            <Avatar seed={me} size={32}/>
                        </Pressable>
                    </View>
                    <View style={styles.body}>
                        {renderHome()
                            if (tab == "home")
                            else (
                                renderSearch()
                                    if (tab == "search")
                                    else (
                                        renderNotifications()
                                            if (tab == "notifications")
                                            else renderProfile()
                                    )
                            )}
                    </View>
                    <View style={styles.tabBar}>
                        <TabButton tabKey="home" icon="home"/>
                        <TabButton tabKey="search" icon="search"/>
                        <TabButton tabKey="notifications" icon="bell"/>
                        <TabButton tabKey="profile" icon="user"/>
                    </View>
                </View>;
        }

        def renderAuth -> JsxElement {
            isSignup = authMode == "signup";
            return
                <View style={styles.page}>
                    <View style={styles.authWrap}>
                        <View style={styles.authLogo}>
                            <Icon
                                name="spark"
                                size={28}
                                color={C.accentText}
                                fill={True}
                                width={2}
                            />
                        </View>
                        <Text style={styles.authTitle}>
                            {("Create your account" if isSignup else "Welcome back")}
                        </Text>
                        <Text style={styles.authSub}>
                            {(
                                "Join LittleX in seconds"
                                    if isSignup
                                    else "Log in to continue"
                            )}
                        </Text>
                        <View style={styles.fieldRow}>
                            <Icon
                                name="at"
                                size={18}
                                color={C.muted}
                                fill={False}
                                width={2}
                            />
                            <TextInput
                                style={styles.fieldInput}
                                value={authUser}
                                placeholder="Username"
                                placeholderTextColor={C.muted}
                                onChangeText={lambda (v: str) { authUser = v; }}
                            />
                        </View>
                        <View style={styles.fieldRow}>
                            <Icon
                                name="lock"
                                size={18}
                                color={C.muted}
                                fill={False}
                                width={2}
                            />
                            <TextInput
                                style={styles.fieldInput}
                                value={authPass}
                                placeholder="Password"
                                placeholderTextColor={C.muted}
                                secureTextEntry={True}
                                onChangeText={lambda (v: str) { authPass = v; }}
                            />
                        </View>
                        {(
                            <View style={styles.fieldRow}>
                                <Icon
                                    name="lock"
                                    size={18}
                                    color={C.muted}
                                    fill={False}
                                    width={2}
                                />
                                <TextInput
                                    style={styles.fieldInput}
                                    value={authPass2}
                                    placeholder="Confirm password"
                                    placeholderTextColor={C.muted}
                                    secureTextEntry={True}
                                    onChangeText={lambda (v: str) { authPass2 = v; }}
                                />
                            </View>
                        )
                            if isSignup
                            else (<View/>)}
                        {(<Text style={styles.errorText}>{authError}</Text>)
                            if (authError != "")
                            else (<View/>)}
                        <Pressable style={styles.primaryBtn} onPress={submitAuth}>
                            <Text style={styles.primaryLabel}>
                                {("Sign up" if isSignup else "Log in")}
                            </Text>
                        </Pressable>
                        <View style={styles.switchRow}>
                            <Text style={styles.switchText}>
                                {(
                                    "Already have an account?"
                                        if isSignup
                                        else "Don't have an account?"
                                )}
                            </Text>
                            <Pressable
                                onPress={lambda {
                                    authMode = "login" if isSignup else "signup";
                                    authError = "";
                                }}
                            >
                                <Text style={styles.switchLink}>
                                    {("Log in" if isSignup else "Sign up")}
                                </Text>
                            </Pressable>
                        </View>
                    </View>
                </View>;
        }

        def renderSplash -> JsxElement {
            return
                <View style={styles.splash}>
                    <Animated.View
                        style={{
                            opacity: intro,
                            transform: [
                                {
                                    scale: intro.interpolate(
                                        {inputRange: [0, 1], outputRange: [0.8, 1]}
                                    )
                                }
                            ],
                            alignItems: "center"
                        }}
                    >
                        <View style={styles.splashLogo}>
                            <Icon
                                name="spark"
                                size={44}
                                color={C.accentText}
                                fill={True}
                                width={2}
                            />
                        </View>
                        <View style={{height: S.lg}}/>
                        <Text style={styles.splashTitle}>LittleX</Text>
                    </Animated.View>
                </View>;
        }

        # ── comment thread modal (bottom sheet) ───────────────────────────────
        def CommentRow(c: any) -> JsxElement {
            return
                <View style={styles.commentRow} key={c._jac_id}>
                    <Avatar seed={c.author} size={36}/>
                    <View style={styles.commentBody}>
                        <Text style={styles.commentName}>
                            {c.author}{" "}
                            <Text style={styles.commentMeta}>
                                @{c.author} · {c.created_at}
                            </Text>
                        </Text>
                        <Text style={styles.commentText}>{c.content}</Text>
                    </View>
                </View>;
        }

        def renderCommentModal -> JsxElement {
            return
                <View style={styles.modalOverlay}>
                    <View style={styles.modalCard}>
                        <View style={styles.modalHead}>
                            <Text style={styles.modalTitle}>Comments</Text>
                            <Pressable onPress={closeComments}>
                                <Icon
                                    name="close"
                                    size={22}
                                    color={C.text}
                                    fill={False}
                                    width={2}
                                />
                            </Pressable>
                        </View>
                        <ScrollView style={styles.modalList}>
                            {(
                                <View style={styles.modalEmpty}>
                                    <Text style={styles.emptyText}>
                                        No comments yet. Start the conversation.
                                    </Text>
                                </View>
                            )
                                if (len(commentList) == 0)
                                else (
                                    <View>
                                        {[
                                            <CommentRow c={c} key={c._jac_id}/>
                                            for c in commentList
                                        ]}
                                    </View>
                                )}
                        </ScrollView>
                        <View style={styles.commentComposer}>
                            <TextInput
                                style={styles.commentInput}
                                value={commentDraft}
                                placeholder="Write a comment..."
                                placeholderTextColor={C.muted}
                                onChangeText={lambda (v: str) { commentDraft = v; }}
                            />
                            <Pressable style={styles.sendBtn} onPress={submitComment}>
                                <Icon
                                    name="send"
                                    size={18}
                                    color={C.accentText}
                                    fill={False}
                                    width={2}
                                />
                            </Pressable>
                        </View>
                    </View>
                </View>;
        }

        return
            <View style={[styles.root, {height: viewport.height}]}>
                {renderSplash()
                    if (screen == "splash")
                    else (renderAuth() if (screen == "auth") else renderApp())}{renderCommentModal()
                    if (commentTid != None)
                    else <View/>}
            </View>;
    }
}
