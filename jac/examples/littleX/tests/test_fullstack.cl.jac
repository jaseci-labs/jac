"""Full-stack littleX test driven through the client (cl) codespace.

This runs in the *client* codespace: the `test` blocks compile to JavaScript
and execute under bun. Walker calls go over the real `@jac/runtime` fetch
bridge (`root spawn` lowers to the same cl->sv request the browser makes), so
the client logic is exercised end-to-end against a live backend.

The backend is declared explicitly via the `sv import` below: the cl test
runner boots that module on an ephemeral port. Because the backend is bound by
import path rather than by filename adjacency, this test runs the same wherever
it lives.

`TestClient` models a browser session: each instance keeps its own auth token
and makes itself the active session (writing `jac_token` to the shared
localStorage shim) before each call, so two users can coexist in one JS
process. Calls run sequentially via `await`, so the swap is race-free.
"""

import from "@jac/runtime" { jacSignup, jacLogin, __setLocalStorage, __getLocalStorage }
sv import from ..social_graph { setup_profile, create_tweet, follow_user, load_feed }

"""One client session: an isolated auth token over the shared runtime."""
obj TestClient {
    has token: str = "";

    """Register a fresh user, log in (mirroring the real frontend flow), and
    capture this session's token."""
    async def signup(username: str, password: str) {
        __setLocalStorage("jac_token", "");
        await jacSignup(username, password);
        await jacLogin(username, password);
        self.token = __getLocalStorage("jac_token") or "";
    }

    """Make this session the active one for the next walker call."""
    def activate {
        __setLocalStorage("jac_token", self.token);
    }
}

test "two users: signup, post, follow, and feed propagation" {
    alice = TestClient();
    bob = TestClient();

    # Two users sign up through the real client signup flow.
    await alice.signup("alice", "secret123");
    await bob.signup("bob", "secret123");
    assert alice.token;
    assert bob.token;
    assert alice.token != bob.token;

    # Each sets up a profile; users only ever see their own.
    alice.activate();
    alice_profile = (root spawn setup_profile(username="alice")).reports[0];
    bob.activate();
    bob_profile = (root spawn setup_profile(username="bob")).reports[0];
    assert alice_profile["username"] == "alice";
    assert bob_profile["username"] == "bob";
    assert alice_profile["id"] != bob_profile["id"];

    # Alice posts a tweet.
    alice.activate();
    tweet = (root spawn create_tweet(content="hello world")).reports[0];
    assert tweet["content"] == "hello world";
    assert tweet["is_mine"] == True;

    # Before following, Alice's tweet is NOT in Bob's feed.
    bob.activate();
    bob_feed_before = (root spawn load_feed(search_query="")).reports[0];
    assert not any(t["content"] == "hello world" for t in bob_feed_before);

    # Bob follows Alice.
    bob.activate();
    follow = (root spawn follow_user(target_id=alice_profile["id"])).reports[0];
    assert follow["success"] == True;

    # Bob now sees Alice's tweet in his feed.
    bob.activate();
    bob_feed_after = (root spawn load_feed(search_query="")).reports[0];
    assert any(t["content"] == "hello world" for t in bob_feed_after);

    # Alice still sees her own tweet.
    alice.activate();
    alice_feed = (root spawn load_feed(search_query="")).reports[0];
    assert any(t["content"] == "hello world" for t in alice_feed);
}
