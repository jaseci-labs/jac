import from jaclang.runtime.runtime { JacRuntime }
import from core.github { RepoMeta }
import from core.leaderboard.scoring { RepoAnalysis, RepoFeatures, ScoreBreakdown }
import os;
import from unittest.mock { patch }
import from tempfile { mkdtemp }
import from jaclang.testing.testing { JacTestClient, TestResponse }

glob SERVER = os.path.join(os.path.dirname(__file__), "social_graph.jac");

test "Genius traverses source and author nodes and respects hourly cooldown" {
    sample = GuideSample(
        title="osp",
        body="Walkers visit nodes.",
        url="https://jaclang.org/docs/latest/osp"
    );
    with patch(jacyac_genius.__module__ + ".random_guide", return_value=sample), patch(
        jacyac_genius.__module__ + ".optional_fact",
        return_value="Walkers explore graphs!\n" + sample.url
    ) as generate {
        root spawn jacyac_genius();
        root spawn jacyac_genius();
        memories = [root-->[?:GeniusMemory]];
        assert len(memories) == 1;
        assert memories[0].previous_guide == "osp";
        topics = [memories[0]->:Studies:->[?:GeniusTopic]];
        assert len(topics) == 1;
        authors = [topics[0]->:PublishesAs:->[?:Profile]];
        assert len(authors) == 1;
        assert authors[0].username == "jacyac_genius";
        assert len([authors[0]->:Post:->[?:Tweet]]) == 1;
        assert generate.call_count == 1;
        memories[0].last_posted = "";
        root spawn jacyac_genius();
        assert len([authors[0]->:Post:->[?:Tweet]]) == 2;
        assert len([memories[0]->:Studies:->[?:GeniusTopic]]) == 1;
    }
}

test "Genius skips failed AI without creating a profile or post" {
    sample = GuideSample(
        title="osp",
        body="Walkers visit nodes.",
        url="https://jaclang.org/docs/latest/osp"
    );
    with patch(jacyac_genius.__module__ + ".random_guide", return_value=sample), patch(
        jacyac_genius.__module__ + ".optional_fact", return_value=""
    ) {
        root spawn jacyac_genius();
        assert not [root-->[?:Profile, username=="jacyac_genius"]];
        memories = [root-->[?:GeniusMemory]];
        assert memories[0].last_posted == "";
    }
}

def make_client -> JacTestClient {
    return JacTestClient.from_file(SERVER, base_path=mkdtemp());
}

def close_client(client: JacTestClient) {
    client.close();
    JacRuntime.set_shared_root_resolver(None);
}

def login_as(client: JacTestClient, username: str, password: str) {
    client.register_user(username, password);
    client.login(username, password);
}

def reports_of(response: TestResponse) -> list {
    data = response.data;
    if data and "reports" in data {
        return list(data["reports"]);
    }
    return [];
}

def first_report(response: TestResponse) -> any {
    reports = reports_of(response);
    return reports[0] if reports else None;
}

def jid_of(reported: any) -> str {
    assert "_jac_id" in reported , f"expected a reported node, got {reported}";
    return str(reported["_jac_id"]);
}

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
            "/walker/add_comment", json={"tweet_id": tweet_id, "content": "nice one"}
        )
    );
    assert commented["success"] == True;

    profile = first_report(client.post("/walker/get_profile", json={}));
    assert len(list(profile["tweets"][0]["comments"])) == 1;

    close_client(client);
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
    client = make_client();
    login_as(client, "alice", "secret123");
    client.post("/walker/setup_profile", json={"username": "alice"});
    client.post("/walker/create_tweet", json={"content": "jac is great"});
    client.post("/walker/create_tweet", json={"content": "python is fine"});

    hits = first_report(client.post("/walker/load_feed", json={"search_query": "jac"}));
    assert len(list(hits)) == 1;
    assert hits[0]["content"] == "jac is great";

    close_client(client);
}

test "trending surfaces hashtags" {
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

def make_offline_client -> JacTestClient {
    os.environ["JAC_SV_SCORING_SERVICE_URL"] = "http://127.0.0.1:9";
    return make_client();
}

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

test "projects must be github repos and stay associated with their owner" {
    client = make_offline_client();
    client.register_user("alice", "secret123");
    client.register_user("bob", "secret123");
    client.login("alice", "secret123");
    client.post("/walker/setup_profile", json={"username": "alice"});

    bad = first_report(
        client.post("/walker/add_project", json={"url": "https://gitlab.com/a/b"})
    );
    assert bad["ok"] == False;
    assert bad["error"] == "bad_url";

    added = first_report(
        client.post("/walker/add_project", json={"url": "github.com/jaseci-labs/jac"})
    );
    assert added["ok"] == False , added;
    assert added["project"] is not None , added;
    project = added["project"];
    assert project["full"] == "jaseci-labs/jac";
    assert project["owner_username"] == "alice";
    assert project["status"] == "error";
    assert project["error"] in ["internal", "fetch_failed"];
    project_id = jid_of(project);

    dup = first_report(
        client.post(
            "/walker/add_project",
            json={"url": "https://github.com/jaseci-labs/jac.git"}
        )
    );
    assert dup["error"] == "duplicate";

    mine = first_report(client.post("/walker/get_profile", json={}));
    assert [p["full"] for p in mine["projects"]] == ["jaseci-labs/jac"];

    client.login("bob", "secret123");
    client.post("/walker/setup_profile", json={"username": "bob"});
    response = client.post("/walker/get_all_projects", json={});
    assert response.ok , response.data;
    explore = first_report(response);
    assert [p["full"] for p in explore] == ["jaseci-labs/jac"];
    assert explore[0]["owner_username"] == "alice";

    alice_view = first_report(
        client.post("/walker/get_user_profile", json={"username": "ALICE"})
    );
    assert alice_view["ok"] == True;
    assert alice_view["bundle"]["profile"]["username"] == "alice";
    assert len(list(alice_view["bundle"]["projects"])) == 1;

    missing = first_report(
        client.post("/walker/get_user_profile", json={"username": "carol"})
    );
    assert missing["ok"] == False;

    forbidden = first_report(
        client.post("/walker/remove_project", json={"project_id": project_id})
    );
    assert forbidden["ok"] == False;
    assert forbidden["error"] == "forbidden";

    client.login("alice", "secret123");
    removed = first_report(
        client.post("/walker/remove_project", json={"project_id": project_id})
    );
    assert removed["ok"] == True;
    after = first_report(client.post("/walker/get_profile", json={}));
    assert after["projects"] == [];
    explore_after = first_report(client.post("/walker/get_all_projects", json={}));
    assert explore_after == [];

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

test "typed scoring payload updates project fields and preserves failure status" {
    project = Project(owner="old", name="repo");
    payload = ScoredPayload(
        ok=True,
        sha="abc123",
        meta=RepoMeta(owner="jac", name="example"),
        an=RepoAnalysis(
            jac_files=2,
            jac_bytes=300,
            other_code_bytes=100,
            features=RepoFeatures(osp=True)
        ),
        breakdown=ScoreBreakdown(total=42, belt="green")
    );
    apply_score(project, payload);
    assert project.full == "jac/example";
    assert project.html_url == "https://github.com/jac/example";
    assert project.jac_pct == 75;
    assert project.features == ["osp"];
    assert project.score == 42;
    assert project.scored_sha == "abc123";
    assert project.status == "scored";
    apply_score(project, ScoredPayload(ok=False, error="fetch_failed"));
    assert project.status == "error";
    assert project.error == "fetch_failed";
}

test "Legacy Ninja Scores migrate once into an archive profile" {
    hub = root ++> BoardHub();
    hub +>:OnBoard():+> RepoEntry(
        full="jac/legacy",
        owner="jac",
        name="legacy",
        score=42,
        breakdown=ScoreBreakdown(total=42, belt="green"),
        belt="green"
    );
    import_legacy();
    import_legacy();
    archives = [root-->[?:Profile, username=="ninja_scores_archive"]];
    assert len(archives) == 1;
    projects = archives[0].projects();
    assert len(projects) == 1;
    assert projects[0].full == "jac/legacy";
    assert projects[0].legacy_import and not projects[0].owner_verified;
    assert projects[0].owner_username == "ninja_scores_archive";
    assert projects[0].breakdown.total == 42;
}
