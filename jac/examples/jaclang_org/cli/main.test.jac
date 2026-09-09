import io;
import from contextlib { redirect_stderr }

def usage_error(argv: list[str]) -> bool {
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

test "score takes a repo and an optional json flag" {
    inv = parse_args(["score", "jaseci-labs/jac"]);
    assert inv.command == "score";
    assert inv.repo == "jaseci-labs/jac";
    assert not inv.as_json;
    assert parse_args(["score", "jaseci-labs/jac", "--json"]).as_json;
    assert usage_error(["score"]);
}

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
    for name in ["score", "docs", "feed", "post"] {
        assert name in text;
    }
}
