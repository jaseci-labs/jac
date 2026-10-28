import asyncio;
import io;
import from contextlib { redirect_stderr }
import from types { SimpleNamespace }
import from unittest.mock { AsyncMock, patch }

test "bridge failures map to distinct exit codes and hints" {
    buf = io.StringIO();
    with redirect_stderr(buf) {
        assert explain_bridge_error(
            BridgeUnavailable(
                app="web", name="docs_status", detail="connection refused"
            )
        )
            == EXIT_UNAVAILABLE;
        assert explain_bridge_error(BridgeTimeout(app="social_graph", name="load_feed"))
            == EXIT_TIMEOUT;
        assert explain_bridge_error(
            BridgeRejected(app="social_graph", name="create_tweet", detail="401")
        )
            == EXIT_REJECTED;
        assert explain_bridge_error(
            BridgeError(app="web", name="docs_sync_tick", detail="500")
        )
            == EXIT_FAILURE;
    }
    text = buf.getvalue();
    assert "web.docs_status is not reachable (connection refused)" in text;
    assert START_HINT in text;
    assert "social_graph.load_feed timed out" in text;
    assert "signed-in identity" in text;
    assert "web.docs_sync_tick failed (500)" in text;
}

test "exit codes are distinct" {
    codes = [
        EXIT_OK,
        EXIT_FAILURE,
        EXIT_USAGE,
        EXIT_UNAVAILABLE,
        EXIT_TIMEOUT,
        EXIT_REJECTED
    ];
    assert len(set(codes)) == len(codes);
}

test "posting quota reports the retry message and returns a rejection exit code" {
    result = SimpleNamespace(reports=[PostingDenied("Try again in 10 seconds.", 10)]);
    with patch(
        run_post.__module__ + ".create_tweet", new=AsyncMock(return_value=result)
    ), patch(run_post.__module__ + ".warn") as warning {
        assert asyncio.run(run_post("hello")) == EXIT_REJECTED;
        warning.assert_called_once_with("Try again in 10 seconds.");
    }
}

def usage_error(argv: list[str]) -> bool;

test "docs takes exactly sync or status" {
    assert parse_args(["docs", "sync"]).action == "sync";
    assert parse_args(["docs", "status"]).action == "status";
    assert usage_error(["docs", "purge"]);
    assert usage_error(["docs"]);
}

test "feed defaults its limit and accepts a search" {
    plain = parse_args(["feed"]);
    assert plain.command == "feed";
    assert plain.limit == DEFAULT_LIMIT;
    assert plain.query == "";
    narrowed = parse_args(["feed", "--limit", "5", "--search", "#jac"]);
    assert narrowed.limit == 5;
    assert narrowed.query == "#jac";
    assert usage_error(["feed", "--limit", "0"]);
    assert usage_error(["feed", "--limit", "five"]);
}

test "post keeps its text verbatim" {
    assert parse_args(["post", "hello  from the cli"]).text == "hello  from the cli";
    assert usage_error(["post"]);
}

test "a missing or unknown command is a usage error" {
    assert usage_error([]);
    assert usage_error(["dance"]);
}

test "the parser names itself jacorg and lists every command" {
    buf = io.StringIO();
    with redirect_stderr(buf) {
        try {
            parse_args(["dance"]);
        } except SystemExit {}
    }
    text = buf.getvalue();
    assert text.startswith("usage: jacorg");
    for name in ["docs", "feed", "post"] {
        assert name in text;
    }
}

impl usage_error(argv: list[str]) -> bool {
    buf = io.StringIO();
    exited = False;
    with redirect_stderr(buf) {
        try {
            parse_args(argv);
        } except SystemExit {
            exited = True;
        }
    }
    return exited and "usage:" in buf.getvalue();
}
