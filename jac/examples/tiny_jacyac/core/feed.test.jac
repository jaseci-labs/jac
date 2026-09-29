import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.testing.testing { JacTestClient }

def call(client: JacTestClient, name: str, fields: dict[str, any] = {}) -> any {
    response = client.post("/function/" + name, json=fields);
    assert response.ok , response.text;
    return response.data["result"];
}

test "accounts own posts and likes; anonymous writes and impersonation fail" {
    with TemporaryDirectory() as folder {
        client = JacTestClient.from_file(
            str(Path(__file__).with_name("feed.jac")), base_path=folder
        );
        try {
            assert not client.post("/function/publish", json={"body": "anonymous"}).ok;
            for name in ["alice", "bob"] {
                assert client.register_user(name, "tiny-secret-123").ok;
            }
            assert client.login("alice", "tiny-secret-123").ok;
            assert call(client, "join", {"username": "alice"}) == "alice";
            assert not client.post("/function/join", json={"username": "bob"}).ok;
            assert not client.post("/function/publish", json={"body": "  "}).ok;
            assert not client.post("/function/publish", json={"body": "x" * 281}).ok;
            post_id = call(client, "publish", {"body": "  hello from Alice  "});
            assert client.login("bob", "tiny-secret-123").ok;
            call(client, "join", {"username": "bob"});
            assert call(client, "toggle_like", {"post_id": post_id}) is True;
            assert call(client, "toggle_like", {"post_id": post_id}) is False;
            assert call(client, "toggle_like", {"post_id": post_id}) is True;
            assert not client.post(
                "/function/remove_post", json={"post_id": post_id}
            ).ok;
            assert client.login("alice", "tiny-secret-123").ok;
            assert call(client, "remove_post", {"post_id": post_id}) is True;
            assert not client.post(
                "/function/toggle_like", json={"post_id": post_id}
            ).ok;
            client.clear_auth();
            assert not client.post("/function/join", json={"username": "alice"}).ok;
        } finally {
            client.close();
            JacRuntime.set_shared_root_resolver(None);
        }
    }
}

test "the example stays under 1000 authored source and configuration lines" {
    project = Path(__file__).parent.parent;
    sources = [
        p
        for p in project.rglob("*.jac")
        if ".jac" not in p.parts and "dist" not in p.parts
    ];
    total = sum(len(p.read_text().splitlines()) for p in sources);
    total += len((project / "jac.toml").read_text().splitlines());
    assert total < 1000 , f"Expected fewer than 1000 lines, got {total}";
}
