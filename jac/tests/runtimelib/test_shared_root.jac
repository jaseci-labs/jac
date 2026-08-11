"""Tests for the shared root surfaced as `root.shared`.

Under a server, `root.shared` resolves through the resolver the server
registers at startup, mapping the internal guest user to its root — so any
request, authenticated or not, can address the shared public graph without
an `allroots()` scan. The runtime floors the shared root's access at
AccessLevel.CONNECT (it is a commons), so no app-side arming grant is needed.
Outside a server there are no separate users, so `root.shared` falls back
to the current context's root.
"""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang { JacRuntime as Jac }
import from jaclang.runtimelib.testing { JacTestClient }

glob FIXTURES = str(Path(__file__).parent / "fixtures");


def make_shared_client(base_path: str) -> JacTestClient {
    return JacTestClient.from_file(
        str((Path(FIXTURES) / "serve_shared_root.jac").resolve()), base_path=base_path
    );
}


test "root.shared falls back to the current root outside a server" {
    # Earlier tests in this process may have registered a server resolver;
    # this test pins the bare-context fallback.
    Jac.set_shared_root_resolver(None);
    assert jid(root.shared) == jid(root);
}


test "anonymous requests all run on the one shared root" {
    with TemporaryDirectory() as tmpdir {
        client = make_shared_client(tmpdir);
        first = client.post("/walker/whereami", json={});
        assert first.ok;
        second = client.post("/walker/whereami", json={});
        assert second.ok;
        # `here` (the request root) and `root.shared` agree, and both
        # anonymous requests landed on the same root.
        (here_id, shared_id) = first.data["reports"];
        assert here_id == shared_id , "anonymous request root is not root.shared";
        assert second.data["reports"][0] == here_id , "shared root not stable across requests";
        client.close();
        Jac.set_shared_root_resolver(None);
    }
}


test "a logged-in user can write the commons before any anonymous request" {
    # The default-CONNECT floor closes the bootstrap race: with NO app-side
    # arming grant and NO prior anonymous traffic, the very first request -
    # from an authenticated user - can attach to the shared graph.
    with TemporaryDirectory() as tmpdir {
        client = make_shared_client(tmpdir);
        client.register_user("alice", "secret123");
        alice_note = client.post("/walker/leave_note", json={"text": "first-write"});
        assert alice_note.ok;
        alice_read = client.post("/walker/read_notes", json={});
        assert alice_read.ok;
        assert alice_read.data["reports"][0] == ["first-write"] , "authenticated-first write to the commons failed";
        # The note landed on the shared root, not on alice's own root.
        client.clear_auth();
        anon_read = client.post("/walker/read_notes", json={});
        assert anon_read.ok;
        assert anon_read.data["reports"][0] == ["first-write"] , "anonymous reader cannot see the commons";
        client.close();
        # Reopen over the same store: anchors now deserialize from L3 with
        # their hashes stamped, so access checks are fully enforced (the
        # in-process working set treats hash==0 anchors as creator-writable).
        # A SECOND user attaching must succeed purely via the floored grant.
        client2 = make_shared_client(tmpdir);
        client2.register_user("carol", "secret123");
        carol_note = client2.post("/walker/leave_note", json={"text": "second-write"});
        assert carol_note.ok;
        carol_read = client2.post("/walker/read_notes", json={});
        assert carol_read.ok;
        assert carol_read.data["reports"][0] == ["first-write", "second-write"] , "floored CONNECT grant not honored after reload";
        client2.close();
        Jac.set_shared_root_resolver(None);
    }
}


test "guest and logged-in users share the shared-root graph" {
    with TemporaryDirectory() as tmpdir {
        client = make_shared_client(tmpdir);
        # Anonymous note lands on the shared root - no arming grant needed.
        anon_note = client.post("/walker/leave_note", json={"text": "from-guest"});
        assert anon_note.ok;
        shared_root_id = anon_note.data["reports"][0];
        # Alice (authenticated, her own root) writes to the SAME shared graph.
        client.register_user("alice", "secret123");
        alice_note = client.post("/walker/leave_note", json={"text": "from-alice"});
        assert alice_note.ok;
        assert alice_note.data["reports"][0] == shared_root_id , "alice's root.shared is not the shared root";
        # Alice reads back both notes through root.shared.
        alice_read = client.post("/walker/read_notes", json={});
        assert alice_read.ok;
        assert alice_read.data["reports"][0] == ["from-alice", "from-guest"];
        # Anonymous readers see both notes too.
        client.clear_auth();
        anon_read = client.post("/walker/read_notes", json={});
        assert anon_read.ok;
        assert anon_read.data["reports"][0] == ["from-alice", "from-guest"];
        client.close();
        Jac.set_shared_root_resolver(None);
    }
}


test "deleting a commons node takes cross-owner edges with it" {
    # The Bin archetype opens WRITE to all via __jac_access__, so bob may
    # delete alice's bin - and the connecting edge alice owns must die with
    # it rather than dangle off the shared root.
    with TemporaryDirectory() as tmpdir {
        client = make_shared_client(tmpdir);
        client.register_user("alice", "secret123");
        made = client.post("/walker/leave_bin", json={"tag": "junk"});
        assert made.ok;
        assert made.data["reports"][0] == 1;
        client.close();
        # Reopen so anchors deserialize from L3 with hashes stamped and
        # access checks are enforced (hash==0 anchors are always writable).
        client2 = make_shared_client(tmpdir);
        client2.register_user("bob", "secret123");
        before = client2.post("/walker/read_bins", json={});
        assert before.ok;
        assert before.data["reports"][0] == ["junk"] , "bob cannot see the commons bin";
        edges_before = before.data["reports"][1];
        cleared = client2.post("/walker/clear_bins", json={});
        assert cleared.ok;
        assert cleared.data["reports"][0] == 1 , "bob's cross-owner delete did not run";
        assert cleared.data["reports"][1] == edges_before - 1 , "alice's edge dangles off the shared root";
        after = client2.post("/walker/read_bins", json={});
        assert after.ok;
        assert after.data["reports"][0] == [] , "deleted bin still reachable";
        client2.close();
        Jac.set_shared_root_resolver(None);
    }
}


test "a cross-owner delete without a write grant no-ops with a warning" {
    # Notes are opened AccessLevel.READ only: bob's delete must leave the note in
    # place, still return 200, and surface a diagnostic in the envelope -
    # a denied delete may be a no-op but never a silent one.
    with TemporaryDirectory() as tmpdir {
        client = make_shared_client(tmpdir);
        client.register_user("alice", "secret123");
        note = client.post("/walker/leave_note", json={"text": "keep"});
        assert note.ok;
        client.close();
        client2 = make_shared_client(tmpdir);
        client2.register_user("bob", "secret123");
        blocked = client2.post("/walker/clear_notes", json={});
        assert blocked.ok , "denied delete should still 200";
        warnings = blocked.data.get("warnings") or [];
        assert len(warnings) > 0 , "denied delete surfaced no warning";
        assert any(["delete" in str(w) for w in warnings]) , "warning does not name the delete";
        readback = client2.post("/walker/read_notes", json={});
        assert readback.ok;
        assert readback.data["reports"][0] == ["keep"] , "read-only note was deleted cross-owner";
        client2.close();
        Jac.set_shared_root_resolver(None);
    }
}


test "an explicitly lowered shared-root level is respected" {
    # Apps may lock the commons down to read-only: a non-NO_ACCESS level set
    # explicitly must NOT be re-floored back to CONNECT.
    with TemporaryDirectory() as tmpdir {
        client = make_shared_client(tmpdir);
        # Seed one note, then lower the commons to read-only as its owner.
        seed = client.post("/walker/leave_note", json={"text": "seeded"});
        assert seed.ok;
        lowered = client.post("/walker/make_readonly", json={});
        assert lowered.ok;
        client.close();
        # Reopen so anchors deserialize from L3 with hashes stamped and the
        # READ level is actually enforced (in-process hash==0 anchors are
        # treated as creator-writable, bypassing checks).
        client2 = make_shared_client(tmpdir);
        client2.register_user("bob", "secret123");
        bob_read = client2.post("/walker/read_notes", json={});
        assert bob_read.ok;
        assert bob_read.data["reports"][0] == ["seeded"] , "read-only commons not readable";
        bob_note = client2.post("/walker/leave_note", json={"text": "blocked"});
        assert bob_note.ok , "write-denied request should still 200 (silent no-op + warning)";
        bob_recheck = client2.post("/walker/read_notes", json={});
        assert bob_recheck.data["reports"][0] == ["seeded"] , "read-only commons accepted a write";
        client2.close();
        Jac.set_shared_root_resolver(None);
    }
}
