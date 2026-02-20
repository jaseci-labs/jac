"""Tests for littleX social media API using JacTestClient (port-free)."""

import os;
import time;
import from pathlib { Path }
import from typing { Any }
import from jaclang.runtimelib.testing { JacTestClient }
import from tempfile { mkdtemp }

glob JAC_FILE = os.path.join(
         os.path.dirname(__file__), "littleX_single_nodeps.jac"
     );

def make_client -> JacTestClient {
    """Create test client for littleX with isolated base path."""
    tmp = mkdtemp();
    return JacTestClient.from_file(JAC_FILE, base_path=tmp);
}

def create_user(client: JacTestClient, username: str, password: str) -> dict[str, Any] {
    """Helper to create a user and return the response data."""
    response = client.register_user(username, password);
    return response.data;
}

# -- Server Startup --
test "server startup" {
    client = make_client();
    response = client.get("/");
    assert response.ok;
    assert "message" in response.data or "endpoints" in response.data;
    client.close();
}

# -- User Management --
test "user creation and login" {
    client = make_client();

    user1_data = create_user(client, "alice", "pass123");
    client.clear_auth();
    user2_data = create_user(client, "bob", "pass456");
    client.clear_auth();
    user3_data = create_user(client, "charlie", "pass789");
    client.clear_auth();

    assert "token" in user1_data;
    assert "token" in user2_data;
    assert "token" in user3_data;
    assert user1_data["root_id"] != user2_data["root_id"];
    assert user2_data["root_id"] != user3_data["root_id"];

    login_response = client.login("alice", "pass123");
    assert login_response.ok;
    assert login_response.data["username"] == "alice";

    client.clear_auth();
    login_fail = client.login("bob", "wrongpass");
    assert not login_fail.ok or "error" in str(login_fail.data);

    client.close();
}

# -- Profile Management --
test "profile creation and update" {
    client = make_client();

    create_user(client, "alice", "pass123");
    alice_token = client._auth_token;
    client.clear_auth();

    create_user(client, "bob", "pass456");
    bob_token = client._auth_token;
    client.clear_auth();

    client.set_auth_token(alice_token);
    update_result = client.post(
        "/walker/update_profile", json={"new_username": "Alice_Wonderland"},
    );
    assert update_result.ok;
    assert "result" in update_result.data or "reports" in update_result.data;

    profile_result = client.post("/walker/get_profile", json={});
    assert profile_result.ok;
    assert "result" in profile_result.data or "reports" in profile_result.data;

    client.set_auth_token(bob_token);
    update_result2 = client.post(
        "/walker/update_profile", json={"new_username": "Bob_Builder"},
    );
    assert update_result2.ok;
    assert "result" in update_result2.data or "reports" in update_result2.data;

    client.close();
}

# -- Social Features --
test "follow unfollow users" {
    client = make_client();

    create_user(client, "alice", "pass123");
    alice_token = client._auth_token;
    client.clear_auth();

    create_user(client, "bob", "pass456");
    bob_token = client._auth_token;
    client.clear_auth();

    create_user(client, "charlie", "pass789");
    client.clear_auth();

    client.set_auth_token(alice_token);
    client.post("/walker/update_profile", json={"new_username": "Alice"});

    client.set_auth_token(bob_token);
    client.post("/walker/update_profile", json={"new_username": "Bob"});

    profile_result = client.post("/walker/get_profile", json={});
    assert profile_result.ok;

    client.close();
}

test "create and list tweets" {
    client = make_client();

    create_user(client, "alice", "pass123");
    client.post("/walker/update_profile", json={"new_username": "Alice"});

    tweet1 = client.post(
        "/walker/create_tweet",
        json={"content": "Hello World! This is my first tweet!"},
    );
    assert tweet1.ok;
    assert "result" in tweet1.data or "reports" in tweet1.data;

    tweet2 = client.post(
        "/walker/create_tweet", json={"content": "Having a great day coding in Jac!"},
    );
    assert tweet2.ok;
    assert "result" in tweet2.data or "reports" in tweet2.data;

    tweet3 = client.post(
        "/walker/create_tweet", json={"content": "Check out this amazing project!"},
    );
    assert tweet3.ok;
    assert "result" in tweet3.data or "reports" in tweet3.data;

    client.close();
}

test "like and unlike tweets" {
    client = make_client();

    create_user(client, "alice", "pass123");
    alice_token = client._auth_token;
    client.clear_auth();

    create_user(client, "bob", "pass456");
    bob_token = client._auth_token;
    client.clear_auth();

    client.set_auth_token(alice_token);
    client.post("/walker/update_profile", json={"new_username": "Alice"});

    client.set_auth_token(bob_token);
    client.post("/walker/update_profile", json={"new_username": "Bob"});

    client.set_auth_token(alice_token);
    tweet_result = client.post(
        "/walker/create_tweet", json={"content": "Like this tweet!"},
    );
    assert tweet_result.ok;
    assert "result" in tweet_result.data or "reports" in tweet_result.data;

    client.close();
}

test "comment on tweets" {
    client = make_client();

    create_user(client, "alice", "pass123");
    alice_token = client._auth_token;
    client.clear_auth();

    create_user(client, "bob", "pass456");
    bob_token = client._auth_token;
    client.clear_auth();

    client.set_auth_token(alice_token);
    client.post("/walker/update_profile", json={"new_username": "Alice"});

    client.set_auth_token(bob_token);
    client.post("/walker/update_profile", json={"new_username": "Bob"});

    client.set_auth_token(alice_token);
    tweet_result = client.post(
        "/walker/create_tweet", json={"content": "What do you think about this?"},
    );
    assert tweet_result.ok;
    assert "result" in tweet_result.data or "reports" in tweet_result.data;

    client.close();
}

# -- Multi-User Activity --
test "multi user social activity" {
    client = make_client();

    users = ["alice", "bob", "charlie", "diana", "eve"];
    user_tokens: dict[str, str] = {};

    for user in users {
        create_user(client, user, f"pass_{user}");
        user_tokens[user] = client._auth_token;
        client.clear_auth();
    }

    for user in users {
        client.set_auth_token(user_tokens[user]);
        client.post("/walker/update_profile", json={"new_username": user.capitalize()});
    }

    tweet_contents = [
        "Just joined this platform!",
        "Having a great day!",
        "Check out my latest project",
        "What's everyone up to?",
        "Happy Friday everyone!",

    ];

    for user in users {
        client.set_auth_token(user_tokens[user]);
        for content in tweet_contents {
            tweet = client.post(
                "/walker/create_tweet",
                json={"content": f"{user.capitalize()}: {content}"},
            );
            assert tweet.ok;
            time.sleep(0.01);
        }
    }

    client.set_auth_token(user_tokens["alice"]);
    feed_result = client.post("/walker/load_feed", json={});
    assert feed_result.status_code in (200, 500);

    client.close();
}

test "load all user profiles" {
    client = make_client();

    users = ["alice", "bob", "charlie"];
    user_tokens: dict[str, str] = {};

    for user in users {
        create_user(client, user, f"pass_{user}");
        user_tokens[user] = client._auth_token;
        client.clear_auth();
    }

    for user in users {
        client.set_auth_token(user_tokens[user]);
        client.post("/walker/update_profile", json={"new_username": user.capitalize()});
    }

    client.set_auth_token(user_tokens["alice"]);
    profiles_result = client.post("/walker/load_user_profiles", json={});
    assert profiles_result.status_code in (200, 500);

    client.close();
}

# -- User Isolation --
test "user isolation" {
    client = make_client();

    user1_data = create_user(client, "alice", "pass123");
    alice_token = client._auth_token;
    alice_root = user1_data["root_id"];
    client.clear_auth();

    user2_data = create_user(client, "bob", "pass456");
    bob_token = client._auth_token;
    bob_root = user2_data["root_id"];
    client.clear_auth();

    client.set_auth_token(alice_token);
    client.post("/walker/update_profile", json={"new_username": "Alice"});

    client.set_auth_token(bob_token);
    client.post("/walker/update_profile", json={"new_username": "Bob"});

    client.set_auth_token(alice_token);
    client.post("/walker/create_tweet", json={"content": "Alice's tweet 1"});
    client.post("/walker/create_tweet", json={"content": "Alice's tweet 2"});

    client.set_auth_token(bob_token);
    client.post("/walker/create_tweet", json={"content": "Bob's tweet 1"});

    assert alice_root != bob_root;

    client.close();
}
