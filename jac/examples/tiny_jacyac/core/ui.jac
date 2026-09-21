import from "@jac/mobui" {
    View,
    Text,
    TextInput,
    Pressable,
    ScrollView,
    useWindowDimensions
}
import from "@jac/runtime" {
    jacSetToken,
    __getApiBaseUrl,
    jacLogout,
    jacIsLoggedIn,
    __getLocalStorage,
    __setLocalStorage
}
import from core.feed { Feed, join, publish, toggle_like, remove_post, load_feed }
import from core.scoring { Score }
import from core.theme { S, C }

def Button(
    label: str, action: Callable, quiet: bool = False, disabled: bool = False
) -> JsxElement {
    return
        <Pressable
            accessibilityRole="button"
            accessibilityLabel={label}
            disabled={disabled}
            onPress={action}
            style={[
                S.button,
                S.quiet if quiet else {},
                {"opacity": 0.45 if disabled else 1}
            ]}
        >
            <Text style={[S.buttonText, S.quietText if quiet else {}]}>{label}</Text>
        </Pressable>;
}

def:pub FeedApp(remote: bool = False) -> JsxElement {
    has feed: Feed = Feed(score=Score()),
        username: str = "",
        password: str = "",
        draft: str = "",
        signup: bool = False,
        logged: bool = False,
        busy: bool = False,
        loading: bool = True,
        error: str = "",
        server: str = "",
        connected: bool = not remote;
    wide = useWindowDimensions().width >= 820;

    async def refresh {
        loading = True;
        error = "";
        try {
            feed = await load_feed();
            if logged and not feed.viewer {
                jacLogout();
                logged = False;
            }
        } except Exception {
            error = "Could not load the feed. Check your connection and try Refresh.";
        } finally {
            loading = False;
        }
    }

    async def connect {
        if not server.startswith("http://") and not server.startswith("https://") {
            error = "Enter a server address starting with http:// or https://.";
            return;
        }
        server = server.rstrip("/");
        globalThis.__JAC_API_BASE_URL__ = server;
        __setLocalStorage("tiny_server", server);
        jacLogout();
        logged = False;
        connected = True;
        error = "";
        await refresh();
    }

    can with entry {
        logged = jacIsLoggedIn();
        username = __getLocalStorage("tiny_username") or "";
        server = __getLocalStorage("tiny_server") or "http://10.0.2.2:8000";
        if remote and __getLocalStorage("tiny_server") {
            globalThis.__JAC_API_BASE_URL__ = server;
            connected = True;
        }
        if connected {
            refresh();
        } else {
            loading = False;
        }
    }

    async def authenticate {
        if busy {
            return;
        }
        busy = True;
        error = "";
        try {
            if not username.strip() or not password {
                error = "Enter a username and password.";
                return;
            }
            identity = {"type": "username", "value": username.strip()};
            payload: dict[str, any] = {
                "credential": {"type": "password", "password": password}
            };
            if signup {
                payload["identities"] = [identity];
            } else {
                payload["identity"] = identity;
            }
            response = await fetch(
                __getApiBaseUrl()
                    + "/api/feed/user/"
                    + ("register" if signup else "login"),
                {
                    "method": "POST",
                    "headers": {"Content-Type": "application/json"},
                    "body": JSON.stringify(payload)
                }
            );
            result: any = await response.json();
            if not response.ok {
                error = result.error.message or "Could not sign in.";
                return;
            }
            jacSetToken(result.data.token);
            username = await join(username.strip());
            __setLocalStorage("tiny_username", username);
            logged = True;
            password = "";
            await refresh();
        } except Exception {
            error = "Could not sign in. Check your connection and try again.";
        } finally {
            busy = False;
        }
    }

    async def act(kind: str, id: str = "") {
        if busy {
            return;
        }
        busy = True;
        error = "";
        try {
            if kind == "post" {
                await publish(draft);
                draft = "";
            } elif kind == "like" {
                await toggle_like(id);
            } elif kind == "delete" {
                await remove_post(id);
            }
            await refresh();
        } except Exception {
            error = "That action did not complete. Refresh and try again.";
        } finally {
            busy = False;
        }
    }

    async def logout {
        jacLogout();
        logged = False;
        password = "";
        draft = "";
        error = "";
        await refresh();
    }

    return
        <ScrollView
            style={S.screen}
            contentContainerStyle={S.page}
            keyboardShouldPersistTaps="handled"
        >
            <View style={S.header}>
                <Text style={S.brand}>
                    tiny jacyac
                    <Text style={S.quietText}>.</Text>
                </Text>
                <Text style={S.eyebrow}>A LITTLE MORE HUMAN</Text>
            </View>
            <View style={S.stack}>
                <Text style={S.eyebrow}>YOUR SMALL CORNER OF THE INTERNET</Text>
                <Text accessibilityRole="header" style={S.title}>
                    Small talk. Good company.
                </Text>
                <Text style={S.subtitle}>
                    Share a thought, celebrate a small win, or just say hello.
                </Text>
            </View>
            {<Text accessibilityRole="alert" style={S.error}>{error}</Text>
                if error
                else None}
            {<View style={S.card}>
                <Text style={S.name}>Connect to your community</Text>
                <TextInput
                    accessibilityLabel="Server address"
                    style={S.input}
                    value={server}
                    autoCapitalize="none"
                    onChangeText={lambda (t: str) { server = t; }}
                />
                <Button label="Connect" action={connect}/>
            </View>
                if not connected
                else <View
                    style={[
                        {
                            "gap": 24,
                            "alignItems": "stretch",
                            "flexDirection": "row" if wide else "column"
                        }
                    ]}
                >
                    <View style={[S.stack, {"flex": 1, "minWidth": 0}]}>
                        {<View style={S.card}>
                            <Text style={S.name}>
                                What’s on your mind, @{feed.viewer}?
                            </Text>
                            <TextInput
                                accessibilityLabel="Your post"
                                style={[S.input, S.composer]}
                                placeholder="Something worth sharing…"
                                placeholderTextColor={C.muted}
                                value={draft}
                                multiline={True}
                                maxLength={280}
                                onChangeText={lambda (t: str) { draft = t; }}
                            />
                            <View style={S.between}>
                                <Text style={S.small}>{len(draft)} / 280</Text>
                                <Button
                                    label={"Posting…" if busy else "Post thought"}
                                    action={lambda { act("post"); }}
                                    disabled={busy or not draft.strip()}
                                />
                            </View>
                        </View>
                            if logged
                            else None}
                        <View style={S.between}>
                            <Text style={S.eyebrow}>THE COMMUNITY FEED</Text>
                            <Button
                                label="Refresh"
                                quiet={True}
                                action={lambda {
                                    error = "";
                                    refresh();
                                }}
                                disabled={loading}
                            />
                        </View>
                        {<Text style={S.small}>Gathering the latest thoughts…</Text>
                            if loading
                            else None}
                        {<View style={S.card}>
                            <Text style={S.name}>A fresh page, a first hello.</Text>
                            <Text style={S.body}>
                                This community is just getting started. Your thought could be the first.
                            </Text>
                        </View>
                            if not loading and not feed.posts
                            else None}
                        {for post in feed.posts {
                            <View
                                key={post.id}
                                testID={"post-" + post.id}
                                style={S.card}
                            >
                                <View style={S.row}>
                                    <View style={S.avatar}>
                                        <Text style={S.name}>
                                            {post.author[:1].upper()}
                                        </Text>
                                    </View>
                                    <View>
                                        <Text style={S.name}>@{post.author}</Text>
                                        <Text style={S.small}>
                                            {post.created[:16].replace("T", " ")} UTC
                                        </Text>
                                    </View>
                                </View>
                                <Text selectable={True} style={S.body}>
                                    {post.body}
                                </Text>
                                <View style={S.between}>
                                    <Button
                                        label={f"{'Unlike' if post.liked else 'Like'} · {post.likes}"}
                                        quiet={True}
                                        action={lambda { act("like", post.id); }}
                                        disabled={busy or not logged}
                                    />
                                    {<Button
                                        label="Delete"
                                        quiet={True}
                                        action={lambda { act("delete", post.id); }}
                                        disabled={busy}
                                    />
                                        if post.mine and logged
                                        else None}
                                </View>
                            </View>
                        }}
                    </View>
                    <View style={[S.stack, {"width": 300 if wide else "100%"}]}>
                        {<View style={S.card}>
                            <Text style={S.eyebrow}>YOUR COMMUNITY REPUTATION</Text>
                            <Text testID="score" style={S.score}>
                                {feed.score.points}
                            </Text>
                            <Text style={S.name}>
                                {feed.score.rank
                                    if feed.score.available
                                    else "Score temporarily unavailable"}
                            </Text>
                            <Text style={S.small}>
                                10 points for sharing a thought. 3 for each like it receives.
                            </Text>
                            <Text style={S.small}>Signed in as @{feed.viewer}</Text>
                            <Button
                                label="Sign out"
                                quiet={True}
                                action={logout}
                                disabled={busy}
                            />
                        </View>
                            if logged
                            else <View style={S.card}>
                                <Text style={S.name}>
                                    {"Make yourself at home."
                                        if signup
                                        else "Good to see you."}
                                </Text>
                                <Text style={S.small}>
                                    Join the conversation with your own account.
                                </Text>
                                <TextInput
                                    accessibilityLabel="Username"
                                    style={S.input}
                                    placeholder="Username"
                                    value={username}
                                    autoCapitalize="none"
                                    autoCorrect={False}
                                    onChangeText={lambda (t: str) { username = t; }}
                                />
                                <TextInput
                                    accessibilityLabel="Password"
                                    style={S.input}
                                    placeholder="Password"
                                    value={password}
                                    secureTextEntry={True}
                                    onChangeText={lambda (t: str) { password = t; }}
                                    onSubmitEditing={authenticate}
                                />
                                <Button
                                    label={"Please wait…"
                                        if busy
                                        else "Create account" if signup else "Sign in"}
                                    action={authenticate}
                                    disabled={busy}
                                />
                                <Button
                                    label={"I already have an account"
                                        if signup
                                        else "New here? Create an account"}
                                    quiet={True}
                                    disabled={busy}
                                    action={lambda {
                                        signup = not signup;
                                        error = "";
                                    }}
                                />
                            </View>}
                        <View style={S.card}>
                            <Text style={S.eyebrow}>A SMALL SPACE FOR GOOD THINGS</Text>
                            <Text style={S.body}>
                                Be curious. Be kind. Every good conversation starts with a little hello.
                            </Text>
                            <Text style={S.small}>
                                The latest 50 thoughts, shared across all your devices.
                            </Text>
                        </View>
                    </View>
                </View>}
            <View style={S.footer}>
                {<Button
                    label="Change server"
                    quiet={True}
                    action={lambda {
                        jacLogout();
                        logged = False;
                        connected = False;
                        error = "";
                        feed = Feed(score=Score());
                    }}
                />
                    if remote and connected
                    else None}
                <Text style={S.small}>
                    Tiny JacYac · A little community, wherever you are.
                </Text>
            </View>
        </ScrollView>;
}
