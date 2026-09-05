import from "@jac/runtime" { jacSignup, jacLogin, __setLocalStorage, __getLocalStorage }
import from core.social_graph { setup_profile, create_tweet, follow_user, load_feed }

obj TestClient {
    has token: str = "";

    async def signup(username: str, password: str) {
        __setLocalStorage("jac_token", "");
        await jacSignup(username, password);
        await jacLogin(username, password);
        self.token = __getLocalStorage("jac_token") or "";
    }

    def activate {
        __setLocalStorage("jac_token", self.token);
    }
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
    alice_profile = (root spawn setup_profile(username="alice")).reports[0];
    bob.activate();
    bob_profile = (root spawn setup_profile(username="bob")).reports[0];
    assert alice_profile["profile"]["username"] == "alice";
    assert bob_profile["profile"]["username"] == "bob";
    assert jid(alice_profile["profile"]) != jid(bob_profile["profile"]);

    alice.activate();
    tweet = (root spawn create_tweet(content="hello world")).reports[0];
    assert tweet["content"] == "hello world";
    assert tweet["author_username"] == "alice";

    bob.activate();
    bob_feed_before = (root spawn load_feed(search_query="")).reports[0];
    assert not any(t["content"] == "hello world" for t in bob_feed_before);

    bob.activate();
    follow = (root spawn follow_user(target_id=jid(alice_profile["profile"]))).reports[
        0
    ];
    assert follow["success"] == True;

    bob.activate();
    bob_feed_after = (root spawn load_feed(search_query="")).reports[0];
    assert any(t["content"] == "hello world" for t in bob_feed_after);

    alice.activate();
    alice_feed = (root spawn load_feed(search_query="")).reports[0];
    assert any(t["content"] == "hello world" for t in alice_feed);
}
