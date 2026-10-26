import from jaclang.runtime.runtime { JacRuntime }
import os;
import from unittest.mock { patch }
import from tempfile { mkdtemp }
import from jaclang.testing.testing { JacTestClient, TestResponse }

glob SERVER = os.path.join(os.path.dirname(__file__), "social_graph.jac");

test "ninjaclaw mentions are found and stripped" {
    assert mentions_ninjaclaw("hey @ninjaclaw how do walkers work?");
    assert mentions_ninjaclaw("@NinjaClaw help");
    assert not mentions_ninjaclaw("email me at a@ninjaclaw.dev");
    assert not mentions_ninjaclaw("@ninjaclawfan hi");
    assert strip_mention("hey @ninjaclaw  how do walkers work?")
        == "hey how do walkers work?";
}

def make_client -> JacTestClient;

def close_client(client: JacTestClient);

def login_as(client: JacTestClient, username: str, password: str);

def reports_of(response: TestResponse) -> list[any];

def first_report(response: TestResponse) -> any;

def jid_of(reported: any) -> str;

test "register and login issues a token" {
    client = make_client();

    register = client.register_user("alice", "secret123");
    assert register.status_code == 201;

    login = client.login("alice", "secret123");
    assert login.ok;
    assert login.data["token"];
    assert client._auth_token is not None;

    bad = client.login("alice", "wrongpass");
    assert not bad.ok;

    close_client(client);
}

test "profile setup and retrieval" {
    client = make_client();
    login_as(client, "alice", "secret123");

    created = first_report(
        client.post("/walker/setup_profile", json={"username": "alice", "bio": "hi"})
    );
    assert created["profile"]["username"] == "alice";
    assert created["profile"]["bio"] == "hi";

    fetched = first_report(client.post("/walker/get_profile", json={}));
    assert jid_of(fetched["profile"]) == jid_of(created["profile"]);
    assert fetched["tweets"] == [];

    updated = first_report(
        client.post("/walker/setup_profile", json={"username": "", "bio": "updated"})
    );
    assert updated["profile"]["username"] == "alice";
    assert updated["profile"]["bio"] == "updated";

    close_client(client);
}

test "create tweet shows up in the feed" {
    client = make_client();
    login_as(client, "alice", "secret123");
    client.post("/walker/setup_profile", json={"username": "alice"});

    tweet = first_report(
        client.post("/walker/create_tweet", json={"content": "hello world"})
    );
    assert tweet["content"] == "hello world";
    assert tweet["author_username"] == "alice";
    assert jid_of(tweet);

    feed = first_report(client.post("/walker/load_feed", json={}));
    assert len(list(feed)) == 1;
    assert feed[0]["content"] == "hello world";

    close_client(client);
}

test "like and comment on a tweet" {
    with patch(posting_limit.__module__ + ".consume_limit", return_value=0) {
        client = make_client();
        login_as(client, "alice", "secret123");
        client.post("/walker/setup_profile", json={"username": "alice"});
        tweet = first_report(
            client.post("/walker/create_tweet", json={"content": "rate this"})
        );
        tweet_id = jid_of(tweet);
        liked = first_report(
            client.post("/walker/like_tweet", json={"tweet_id": tweet_id})
        );
        assert liked["liked"] == True;
        assert "alice" in list(liked["likes"]);
        unliked = first_report(
            client.post("/walker/like_tweet", json={"tweet_id": tweet_id})
        );
        assert unliked["liked"] == False;
        commented = first_report(
            client.post(
                "/walker/add_comment",
                json={"tweet_id": tweet_id, "content": "nice one"}
            )
        );
        assert commented["success"] == True;
        profile = first_report(client.post("/walker/get_profile", json={}));
        assert len(list(profile["tweets"][0]["comments"])) == 1;
        close_client(client);
    }
}

test "delete a tweet removes it from the feed" {
    client = make_client();
    login_as(client, "alice", "secret123");
    client.post("/walker/setup_profile", json={"username": "alice"});
    tweet = first_report(
        client.post("/walker/create_tweet", json={"content": "temporary"})
    );

    deleted = first_report(
        client.post("/walker/delete_tweet", json={"tweet_id": jid_of(tweet)})
    );
    assert deleted["success"] == True;

    feed = first_report(client.post("/walker/load_feed", json={}));
    assert len(list(feed)) == 0;

    close_client(client);
}

test "search filters the feed by content" {
    with patch(posting_limit.__module__ + ".consume_limit", return_value=0) {
        client = make_client();
        login_as(client, "alice", "secret123");
        client.post("/walker/setup_profile", json={"username": "alice"});
        client.post("/walker/create_tweet", json={"content": "jac is great"});
        client.post("/walker/create_tweet", json={"content": "python is fine"});
        hits = first_report(
            client.post("/walker/load_feed", json={"search_query": "jac"})
        );
        assert len(list(hits)) == 1;
        assert hits[0]["content"] == "jac is great";
        close_client(client);
    }
}

test "trending surfaces hashtags" {
    with patch(posting_limit.__module__ + ".consume_limit", return_value=0) {
        client = make_client();
        login_as(client, "alice", "secret123");
        client.post("/walker/setup_profile", json={"username": "alice"});
        client.post("/walker/create_tweet", json={"content": "learning #jac today"});
        client.post("/walker/create_tweet", json={"content": "#jac is fun"});
        client.post("/walker/create_tweet", json={"content": "also #osp"});
        trending = first_report(client.post("/walker/get_trending", json={}));
        tags = {row["tag"]: row["count"] for row in trending};
        assert tags["#jac"] == 2;
        assert tags["#osp"] == 1;
        close_client(client);
    }
}

test "follow and unfollow another user" {
    client = make_client();
    client.register_user("alice", "secret123");
    client.register_user("bob", "secret123");

    client.login("bob", "secret123");
    bob_profile = first_report(
        client.post("/walker/setup_profile", json={"username": "bob"})
    );
    bob_id = jid_of(bob_profile["profile"]);

    client.login("alice", "secret123");
    client.post("/walker/setup_profile", json={"username": "alice"});

    followed = client.post("/walker/follow_user", json={"target_id": bob_id});
    assert first_report(followed)["success"] == True;

    after_follow = first_report(client.post("/walker/get_profile", json={}));
    assert len(list(after_follow["following"])) == 1;
    assert after_follow["following"][0]["username"] == "bob";

    client.post("/walker/unfollow_user", json={"target_id": bob_id});
    after_unfollow = first_report(client.post("/walker/get_profile", json={}));
    assert len(list(after_unfollow["following"])) == 0;

    close_client(client);
}

test "feed includes tweets from followed users" {
    client = make_client();
    client.register_user("alice", "secret123");
    client.register_user("bob", "secret123");

    client.login("bob", "secret123");
    bob_profile = first_report(
        client.post("/walker/setup_profile", json={"username": "bob"})
    );
    client.post("/walker/create_tweet", json={"content": "bob's update"});

    client.login("alice", "secret123");
    client.post("/walker/setup_profile", json={"username": "alice"});
    client.post("/walker/create_tweet", json={"content": "alice's update"});
    client.post(
        "/walker/follow_user", json={"target_id": jid_of(bob_profile["profile"])}
    );

    feed = first_report(client.post("/walker/load_feed", json={}));
    contents = {t["content"] for t in feed};
    assert "alice's update" in contents;
    assert "bob's update" in contents;

    close_client(client);
}

test "directory lists every registered profile" {
    client = make_client();
    client.register_user("alice", "secret123");
    client.register_user("bob", "secret123");

    client.login("alice", "secret123");
    client.post("/walker/setup_profile", json={"username": "alice"});
    client.login("bob", "secret123");
    client.post("/walker/setup_profile", json={"username": "bob"});

    everyone = first_report(client.post("/walker/get_all_profiles", json={}));
    names = {u["username"] for u in everyone};
    assert "alice" in names;
    assert "bob" in names;

    close_client(client);
}

test "channel create, join, post and detail" {
    client = make_client();
    client.register_user("alice", "secret123");
    client.register_user("bob", "secret123");

    client.login("alice", "secret123");
    client.post("/walker/setup_profile", json={"username": "alice"});
    channel = first_report(
        client.post(
            "/walker/create_channel", json={"name": "jac-lang", "description": "chat"}
        )
    );
    channel_id = jid_of(channel["channel"]);
    assert channel["is_member"] == True;
    assert channel["member_count"] == 1;

    client.post(
        "/walker/create_channel_tweet",
        json={"channel_id": channel_id, "content": "welcome to the channel"}
    );

    client.login("bob", "secret123");
    client.post("/walker/setup_profile", json={"username": "bob"});
    joined = first_report(
        client.post("/walker/join_channel", json={"channel_id": channel_id})
    );
    assert joined["success"] == True;

    listing = first_report(client.post("/walker/get_channels", json={}));
    assert len(list(listing)) == 1;
    assert listing[0]["member_count"] == 2;

    detail = first_report(
        client.post("/walker/get_channel_detail", json={"channel_id": channel_id})
    );
    assert detail["is_member"] == True;
    assert len(list(detail["posts"])) == 1;
    assert detail["posts"][0]["content"] == "welcome to the channel";

    close_client(client);
}

test "users only see their own profile via get_profile" {
    client = make_client();
    client.register_user("alice", "secret123");
    client.register_user("bob", "secret123");

    client.login("alice", "secret123");
    alice = first_report(
        client.post("/walker/setup_profile", json={"username": "alice"})
    );

    client.login("bob", "secret123");
    bob = first_report(client.post("/walker/setup_profile", json={"username": "bob"}));

    assert jid_of(alice["profile"]) != jid_of(bob["profile"]);
    assert bob["profile"]["username"] == "bob";

    close_client(client);
}

glob PNG_1PX: str = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==";

test "update_profile validates and stores standard fields" {
    client = make_client();
    login_as(client, "alice", "secret123");
    client.post("/walker/setup_profile", json={"username": "alice"});

    saved = first_report(
        client.post(
            "/walker/update_profile",
            json={
                "display_name": "  Alice Ninja ",
                "bio": "building in jac",
                "location": "Ann Arbor",
                "website": "alice.dev",
                "github": "https://github.com/alice-ninja"
            }
        )
    );
    assert saved["ok"] == True , saved;
    profile = saved["bundle"]["profile"];
    assert profile["display_name"] == "Alice Ninja";
    assert profile["website"] == "https://alice.dev";
    assert profile["github"] == "alice-ninja";
    assert profile["location"] == "Ann Arbor";

    bad_handle = first_report(
        client.post("/walker/update_profile", json={"github": "not a handle!"})
    );
    assert bad_handle["ok"] == False;
    assert "GitHub" in bad_handle["error"];

    bad_site = first_report(
        client.post("/walker/update_profile", json={"website": "http://"})
    );
    assert bad_site["ok"] == False;

    cleared = first_report(
        client.post("/walker/update_profile", json={"display_name": "Alice"})
    );
    assert cleared["ok"] == True;
    assert cleared["bundle"]["profile"]["location"] == "";
    assert cleared["bundle"]["profile"]["github"] == "";

    close_client(client);
}

test "avatar upload round-trips and is visible to other users" {
    client = make_client();
    client.register_user("alice", "secret123");
    client.register_user("bob", "secret123");
    client.login("alice", "secret123");
    client.post("/walker/setup_profile", json={"username": "alice"});

    rejected = first_report(
        client.post(
            "/walker/set_avatar", json={"data_url": "data:text/plain;base64,aGVsbG8="}
        )
    );
    assert rejected["ok"] == False;

    forged = first_report(
        client.post(
            "/walker/set_avatar", json={"data_url": "data:image/jpeg;base64,aGVsbG8="}
        )
    );
    assert forged["ok"] == False;

    stored = first_report(
        client.post("/walker/set_avatar", json={"data_url": PNG_1PX})
    );
    assert stored["ok"] == True , stored;
    assert stored["avatar_url"] == PNG_1PX;
    assert stored["avatar_v"] != "";

    me = first_report(client.post("/walker/get_profile", json={}));
    assert me["profile"]["avatar_v"] == stored["avatar_v"];

    client.login("bob", "secret123");
    client.post("/walker/setup_profile", json={"username": "bob"});
    seen = first_report(
        client.post(
            "/walker/get_avatars", json={"usernames": ["alice", "bob", "nobody"]}
        )
    );
    assert seen["alice"] == PNG_1PX;
    assert "bob" not in seen;

    client.login("alice", "secret123");
    gone = first_report(client.post("/walker/clear_avatar", json={}));
    assert gone["ok"] == True;
    me_again = first_report(client.post("/walker/get_profile", json={}));
    assert me_again["profile"]["avatar_v"] == "";

    close_client(client);
}

test "profile editor can clear a bio without losing other fields" {
    client = make_client();
    login_as(client, "bio_editor", "secret123");
    client.post(
        "/walker/setup_profile", json={"username": "bio_editor", "bio": "Original"}
    );
    result = first_report(
        client.post(
            "/walker/update_profile",
            json={"display_name": "Bio Editor", "bio": "", "location": "New York"}
        )
    );
    assert result["ok"];
    profile = first_report(client.post("/walker/get_profile", json={}))["profile"];
    assert profile["bio"] == "";
    assert profile["display_name"] == "Bio Editor";
    assert profile["location"] == "New York";
    close_client(client);
}

test "post validation is enforced for non-UI callers" {
    client = make_client();
    login_as(client, "post_limits", "secret123");
    client.post("/walker/setup_profile", json={"username": "post_limits"});
    client.post("/walker/create_tweet", json={"content": "   "});
    client.post("/walker/create_tweet", json={"content": "x" * 281});
    assert first_report(client.post("/walker/load_feed", json={})) == [];
    client.post("/walker/create_tweet", json={"content": "x" * 280});
    assert len(first_report(client.post("/walker/load_feed", json={}))) == 1;
    close_client(client);
}

test "posts comments and channel posts use the same account quota before mutation" {
    me = root ++> Profile(username='quota_user');
    tweet = me +>:Post():+> Tweet(content='original', author_username='quota_user');
    channel = me +>:Member():+> Channel(
        name='quota-test', description='', creator_username='quota_user'
    );
    with patch(
        create_tweet.__module__ + '.posting_limit',
        return_value=PostingDenied('Wait', 10)
    ) as quota {
        denied = (root spawn create_tweet(content='blocked')).reports[0];
        assert isinstance(denied, PostingDenied);
        assert denied.message == 'Wait';
        assert len([me->:Post:->[?:Tweet]]) == 1;
        root spawn add_comment(tweet_id=jid(tweet), content='blocked comment');
        assert not tweet.comments;
        root spawn create_channel_tweet(
            channel_id=jid(channel), content='blocked channel post'
        );
        assert not [channel->:ChannelPost:->[?:Tweet]];
        assert quota.call_count == 3;
        for call in quota.call_args_list {
            assert call.args[0] == jid(root);
        }
    }
}

test "daily quota denies after burst check and database failures deny posting" {
    with patch(
        posting_limit.__module__ + '.consume_limit', side_effect=[0, 123]
    ) as quota {
        denied = posting_limit('account');
        assert denied is not None;
        assert denied.retry_after_seconds == 123;
        quota.assert_any_call('jacyac-post-burst', 'account', 1, 10);
        quota.assert_any_call('jacyac-post-day', 'account', 50, 86400);
    }
    with patch(posting_limit.__module__ + '.consume_limit', return_value=-1) {
        assert posting_limit('account') is not None;
    }
}

impl make_client -> JacTestClient {
    return JacTestClient.from_file(SERVER, base_path=mkdtemp());
}

impl close_client(client: JacTestClient) {
    client.close();
    JacRuntime.set_shared_root_resolver(None);
}

impl login_as(client: JacTestClient, username: str, password: str) {
    client.register_user(username, password);
    client.login(username, password);
}

impl reports_of(response: TestResponse) -> list[any] {
    data = response.data;
    if data and "reports" in data {
        return list(data["reports"]);
    }
    return [];
}

impl first_report(response: TestResponse) -> any {
    reports = reports_of(response);
    return reports[0] if reports else None;
}

impl jid_of(reported: any) -> str {
    assert "_jac_id" in reported , f"expected a reported node, got {reported}";
    return str(reported["_jac_id"]);
}

test "the desk never asks an old question twice, however many posts follow" {
    desk = NinjaclawDesk(started_at="2026-01-01T00:00:00Z");
    help = Channel(name="help");
    tweets = {
        "t1": Tweet(
            content="@ninjaclaw how do walkers work?",
            author_username="ann",
            created_at="2026-01-01T00:01:00Z"
        )
    };
    assert len(desk_asks(desk, help, tweets)) == 1;
    assert desk_asks(desk, help, tweets) == [];
    tweets["t2"] = Tweet(
        content="@ninjaclaw what is a node?",
        author_username="bob",
        created_at="2026-01-01T01:00:00Z"
    );
    later = desk_asks(desk, help, tweets);
    assert [a.question for a in later] == ["what is a node?"];
    assert "t1" not in desk.recent_keys , "keys older than the scan window are dropped";
    assert desk_asks(desk, help, tweets) == [] , "an aged-out key must not become new again";
}
