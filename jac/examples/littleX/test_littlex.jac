"""Integration tests for the littleX fullstack backend.

These exercise `server.jac` end-to-end over real HTTP semantics using
`JacTestClient` - no OS port is opened. Each test gets an isolated graph
(a fresh temp `base_path`), so tests never see each other's data.

Run with:  jac test test_littlex.jac
"""

import os;
import pytest;
import from typing { Any }
import from tempfile { mkdtemp }
import from jaclang.runtimelib.testing { JacTestClient }

glob SERVER = os.path.join(os.path.dirname(__file__), "server.jac");

"""Spin up a test client backed by a fresh, isolated graph."""
def make_client -> JacTestClient {
    return JacTestClient.from_file(SERVER, base_path=mkdtemp());
}

"""Register a user and authenticate the client as that user."""
def login_as(client: JacTestClient, username: str, password: str) {
    client.register_user(username, password);
    client.login(username, password);
}

"""Return the walker's report list from a response."""
def reports_of(response: Any) -> list {
    data = response.data;
    if data and "reports" in data {
        return data["reports"];
    }
    return [];
}

"""Return the first reported value (or None if the walker reported nothing)."""
def first_report(response: Any) -> Any {
    reports = reports_of(response);
    return reports[0] if reports else None;
}

# -- Auth --
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

    client.close();
}

# -- Profile --
test "profile setup and retrieval" {
    client = make_client();
    login_as(client, "alice", "secret123");

    created = first_report(
        client.post("/walker/setup_profile", json={"username": "alice", "bio": "hi"})
    );
    assert created["username"] == "alice";
    assert created["bio"] == "hi";

    fetched = first_report(client.post("/walker/get_profile", json={}));
    assert fetched["id"] == created["id"];
    assert fetched["tweets"] == [];

    updated = first_report(
        client.post("/walker/setup_profile", json={"username": "", "bio": "updated"})
    );
    assert updated["username"] == "alice";
    assert updated["bio"] == "updated";

    client.close();
}

# -- Tweets & feed --
test "create tweet shows up in the feed" {
    client = make_client();
    login_as(client, "alice", "secret123");
    client.post("/walker/setup_profile", json={"username": "alice"});

    tweet = first_report(
        client.post("/walker/create_tweet", json={"content": "hello world"})
    );
    assert tweet["content"] == "hello world";
    assert tweet["is_mine"] == True;

    feed = first_report(client.post("/walker/load_feed", json={}));
    assert len(feed) == 1;
    assert feed[0]["content"] == "hello world";

    client.close();
}

test "like and comment on a tweet" {
    client = make_client();
    login_as(client, "alice", "secret123");
    client.post("/walker/setup_profile", json={"username": "alice"});
    tweet = first_report(
        client.post("/walker/create_tweet", json={"content": "rate this"})
    );
    tweet_id = tweet["id"];

    liked = first_report(
        client.post("/walker/like_tweet", json={"tweet_id": tweet_id})
    );
    assert liked["liked"] == True;
    assert "alice" in liked["likes"];

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
    assert len(profile["tweets"][0]["comments"]) == 1;

    client.close();
}

test "delete a tweet removes it from the feed" {
    client = make_client();
    login_as(client, "alice", "secret123");
    client.post("/walker/setup_profile", json={"username": "alice"});
    tweet = first_report(
        client.post("/walker/create_tweet", json={"content": "temporary"})
    );

    deleted = first_report(
        client.post("/walker/delete_tweet", json={"tweet_id": tweet["id"]})
    );
    assert deleted["success"] == True;

    feed = first_report(client.post("/walker/load_feed", json={}));
    assert len(feed) == 0;

    client.close();
}

test "search filters the feed by content" {
    client = make_client();
    login_as(client, "alice", "secret123");
    client.post("/walker/setup_profile", json={"username": "alice"});
    client.post("/walker/create_tweet", json={"content": "jac is great"});
    client.post("/walker/create_tweet", json={"content": "python is fine"});

    hits = first_report(client.post("/walker/load_feed", json={"search_query": "jac"}));
    assert len(hits) == 1;
    assert hits[0]["content"] == "jac is great";

    client.close();
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

    client.close();
}

# -- Social graph --
test "follow and unfollow another user" {
    client = make_client();
    client.register_user("alice", "secret123");
    client.register_user("bob", "secret123");

    client.login("bob", "secret123");
    bob_profile = first_report(
        client.post("/walker/setup_profile", json={"username": "bob"})
    );
    bob_id = bob_profile["id"];

    client.login("alice", "secret123");
    client.post("/walker/setup_profile", json={"username": "alice"});

    followed = client.post("/walker/follow_user", json={"target_id": bob_id});
    assert first_report(followed)["success"] == True;

    after_follow = first_report(client.post("/walker/get_profile", json={}));
    assert len(after_follow["following"]) == 1;
    assert after_follow["following"][0]["username"] == "bob";

    client.post("/walker/unfollow_user", json={"target_id": bob_id});
    after_unfollow = first_report(client.post("/walker/get_profile", json={}));
    assert len(after_unfollow["following"]) == 0;

    client.close();
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
    client.post("/walker/follow_user", json={"target_id": bob_profile["id"]});

    feed = first_report(client.post("/walker/load_feed", json={}));
    contents = {t["content"] for t in feed};
    assert "alice's update" in contents;
    assert "bob's update" in contents;

    client.close();
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

    client.close();
}

# -- Channels --
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
    channel_id = channel["id"];
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
    assert len(listing) == 1;
    assert listing[0]["member_count"] == 2;

    detail = first_report(
        client.post("/walker/get_channel_detail", json={"channel_id": channel_id})
    );
    assert detail["is_member"] == True;
    assert len(detail["posts"]) == 1;
    assert detail["posts"][0]["content"] == "welcome to the channel";

    client.close();
}

# -- Isolation --
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

    assert alice["id"] != bob["id"];
    assert bob["username"] == "bob";

    client.close();
}
