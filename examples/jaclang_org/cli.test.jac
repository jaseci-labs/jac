def usage_error(argv: list[str]) -> bool {
    return parse_args(argv).error != "";
}

test "a crossing's failures map to distinct exit codes" {
    assert explain_bridge_error(RemoteUnavailable(endpoint="docs_status", detail="refused"))
        == EXIT_UNAVAILABLE;
    assert explain_bridge_error(RemoteTimeout(endpoint="load_feed")) == EXIT_TIMEOUT;
    assert explain_bridge_error(RemoteRejected(endpoint="create_tweet", detail="401"))
        == EXIT_REJECTED;
    assert explain_bridge_error(RemoteError(endpoint="docs_sync_tick", detail="500"))
        == EXIT_FAILURE;
}

test "exit codes are distinct" {
    codes = [EXIT_OK, EXIT_FAILURE, EXIT_USAGE, EXIT_UNAVAILABLE, EXIT_TIMEOUT, EXIT_REJECTED];
    assert len(set(codes)) == len(codes);
}

test "docs takes exactly sync or status" {
    assert parse_args(["docs", "sync"]).inv.action == "sync";
    assert parse_args(["docs", "status"]).inv.action == "status";
    assert usage_error(["docs", "purge"]);
    assert usage_error(["docs"]);
}

test "feed defaults its limit and accepts a search" {
    plain = parse_args(["feed"]).inv;
    assert plain.command == "feed";
    assert plain.limit == DEFAULT_LIMIT;
    assert plain.query == "";
    narrowed = parse_args(["feed", "--limit", "5", "--search", "#jac"]).inv;
    assert narrowed.limit == 5;
    assert narrowed.query == "#jac";
    assert usage_error(["feed", "--limit", "0"]);
    assert usage_error(["feed", "--limit", "five"]);
}

test "post keeps its text verbatim" {
    assert parse_args(["post", "hello  from the cli"]).inv.text == "hello  from the cli";
    assert usage_error(["post"]);
}
