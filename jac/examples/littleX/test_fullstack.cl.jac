"""Full-stack littleX test driven through the client (cl) codespace.

This runs in the *client* codespace: the `test` blocks compile to JavaScript
and execute under bun. Every server call goes through the real `@jac/runtime`
fetch bridge (`__doWalkerFetch`) against a live littleX backend that the cl
test runner boots automatically on an ephemeral port (the sibling `server.jac`).

`TestClient` models a browser session: each instance keeps its own auth token
and makes itself the active session (writing `jac_token` to the shared
localStorage shim) right before each call, so two users can coexist in one JS
process. Calls run sequentially via `await`, so the swap is race-free.
"""

import from "@jac/runtime" {
    jacSignup,
    jacLogin,
    __doWalkerFetch,
    __setLocalStorage,
    __getLocalStorage
}

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

    """Make this session active, spawn a walker via the real fetch bridge, and
    return its `report`-ed values."""
    async def spawn(walker_name: str, fields: dict = {}) -> list {
        __setLocalStorage("jac_token", self.token);
        result = await __doWalkerFetch(walker_name, "", fields);
        if result and ("result" in result) and ("reports" in result["result"]) {
            return result["result"]["reports"];
        }
        return [];
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
    alice_profile = (await alice.spawn("setup_profile", {"username": "alice"}))[0];
    bob_profile = (await bob.spawn("setup_profile", {"username": "bob"}))[0];
    assert alice_profile["username"] == "alice";
    assert bob_profile["username"] == "bob";
    assert alice_profile["id"] != bob_profile["id"];

    # Alice posts a tweet.
    tweet = (await alice.spawn("create_tweet", {"content": "hello world"}))[0];
    assert tweet["content"] == "hello world";
    assert tweet["is_mine"] == True;

    # Before following, Alice's tweet is NOT in Bob's feed.
    bob_feed_before = (await bob.spawn("load_feed", {}))[0];
    assert not any(t["content"] == "hello world" for t in bob_feed_before);

    # Bob follows Alice.
    follow = (await bob.spawn("follow_user", {"target_id": alice_profile["id"]}))[0];
    assert follow["success"] == True;

    # Bob now sees Alice's tweet in his feed.
    bob_feed_after = (await bob.spawn("load_feed", {}))[0];
    assert any(t["content"] == "hello world" for t in bob_feed_after);

    # Alice still sees her own tweet.
    alice_feed = (await alice.spawn("load_feed", {}))[0];
    assert any(t["content"] == "hello world" for t in alice_feed);
}
