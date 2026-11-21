import from "@jac/runtime" { __getApiBaseUrl, __setLocalStorage }
import from core.social_graph { setup_profile, create_tweet, follow_user, load_feed }

obj TestClient {
    has token: str = "";

    async def signup(username: str, password: str);
    def activate;
}

test "two users: signup, post, follow, and feed propagation" {
    alice = TestClient();
    bob = TestClient();

    await alice.signup("alice", "secret123");
    await bob.signup("bob", "secret123");
    assert alice.token;
    assert bob.token;
    assert alice.token != bob.token;

    alice.activate();
    alice_profile = (await (root spawn setup_profile(username="alice"))).reports[0];
    bob.activate();
    bob_profile = (await (root spawn setup_profile(username="bob"))).reports[0];
    assert alice_profile["profile"]["username"] == "alice";
    assert bob_profile["profile"]["username"] == "bob";
    assert jid(alice_profile["profile"]) != jid(bob_profile["profile"]);

    alice.activate();
    tweet = (await (root spawn create_tweet(content="hello world"))).reports[0];
    assert tweet["content"] == "hello world";
    assert tweet["author_username"] == "alice";

    bob.activate();
    bob_feed_before = (await (root spawn load_feed(search_query=""))).reports[0];
    assert not any(t["content"] == "hello world" for t in bob_feed_before);

    bob.activate();
    follow = (await (root spawn follow_user(target_id=jid(alice_profile["profile"])))).reports[0];
    assert follow["success"] == True;

    bob.activate();
    bob_feed_after = (await (root spawn load_feed(search_query=""))).reports[0];
    assert any(t["content"] == "hello world" for t in bob_feed_after);

    alice.activate();
    alice_feed = (await (root spawn load_feed(search_query=""))).reports[0];
    assert any(t["content"] == "hello world" for t in alice_feed);
}

impl TestClient.signup(username: str, password: str) {
    # No one is at a form in a test: the account is made by the accounts
    # plugin's own action, which is what its form posts.
    response = await fetch(
        __getApiBaseUrl() + "/__jac/auth/register",
        {
            "method": "POST",
            "headers": {"Content-Type": "application/json"},
            "body": JSON.stringify({
                "username": username,
                "email": username + "@example.com",
                "password": password,
            }),
        },
    );
    reply: any = await response.json();
    assert reply.ok;
    self.token = reply.data.token;
}

impl TestClient.activate {
    __setLocalStorage("jac_token", self.token);
}
