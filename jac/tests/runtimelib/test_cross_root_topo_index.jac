"""Cross-root graph query tests for the topology-index optimizer.

The topology index lives on each root anchor and indexes the edges that
root *originated*. When a query crosses into another user's owned
subgraph, the index used to silently miss those edges -- the global
edge walk (with `JAC_TOPOLOGY_INDEX=0`) returns the right answer, but
the index path returned an empty / undercounted set.

These tests pin down both failure shapes against a real
`JacTestClient` (long-lived runtime context, the regime where the
optimizer actually runs):

  * a 2-hop forward chain that crosses into another user's edges, and
  * a 1-hop reverse query whose incoming edges are owned by other users.
"""

import os;
import from pathlib { Path }
import from tempfile { mkdtemp }
import jaclang;
import from jaclang.runtimelib.testing { JacTestClient }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     FIXTURE = os.path.join(
         JAC_ROOT, "tests", "runtimelib", "fixtures", "cross_root_topo_index.jac"
     );

"""Force the topology-index optimizer on for the duration of `fn`."""
def with_topo_index(fn: callable) {
    prev = os.environ.get("JAC_TOPOLOGY_INDEX");
    os.environ["JAC_TOPOLOGY_INDEX"] = "1";
    try {
        fn();
    } finally {
        if prev is None {
            del os.environ["JAC_TOPOLOGY_INDEX"];
        } else {
            os.environ["JAC_TOPOLOGY_INDEX"] = prev;
        }
    }
}

"""Pull the first report value from a JacTestClient response."""
def first_report(response: any) -> any {
    data = response.data;
    if data and "reports" in data {
        reports = data["reports"];
        return reports[0] if reports else None;
    }
    return None;
}

test "cross-root forward chain returns followed user's tweets" {
    def _body {
        client = JacTestClient.from_file(FIXTURE, base_path=mkdtemp());
        try {
            # Bob registers, sets up a profile, posts a tweet.
            client.register_user("bob", "secret123");
            client.login("bob", "secret123");
            bob_profile_id = first_report(
                client.post("/walker/setup_profile_only", json={"username": "bob"})
            );
            client.post("/walker/post_tweet", json={"content": "hello world"});

            # Alice registers, sets up a profile, follows bob.
            client.register_user("alice", "secret123");
            client.login("alice", "secret123");
            client.post("/walker/setup_profile_only", json={"username": "alice"});
            client.post("/walker/follow_target", json={"target_id": bob_profile_id});

            # The chained query crosses alice's Follow edge into bob's
            # Post-edge subgraph; should reach bob's one tweet.
            count = first_report(client.post("/walker/query_follow_chain", json={}));
            assert count == 1 , f"Expected 1 reachable tweet, got {count!r}";
        } finally {
            client.close();
        }
    }
    with_topo_index(_body);
}

test "cross-root reverse query counts members across roots" {
    def _body {
        client = JacTestClient.from_file(FIXTURE, base_path=mkdtemp());
        try {
            # Alice creates the channel.
            client.register_user("alice", "secret123");
            client.login("alice", "secret123");
            client.post("/walker/setup_profile_only", json={"username": "alice"});
            channel_id = first_report(
                client.post("/walker/create_channel", json={"name": "lounge"})
            );

            # Bob joins.
            client.register_user("bob", "secret123");
            client.login("bob", "secret123");
            client.post("/walker/setup_profile_only", json={"username": "bob"});
            client.post("/walker/join_channel", json={"channel_id": channel_id});

            # Reverse query [channel<-Member<-Profile] from alice must
            # see bob's Member edge (which bob owns).
            client.login("alice", "secret123");
            count = first_report(
                client.post(
                    "/walker/query_channel_members", json={"channel_id": channel_id}
                )
            );
            assert count == 2 , f"Expected 2 members, got {count!r}";
        } finally {
            client.close();
        }
    }
    with_topo_index(_body);
}
