import argparse;
import asyncio;
import sys;
import from jaclang.server.bridge {
    BridgeError,
    BridgeRejected,
    BridgeTimeout,
    BridgeUnavailable
}

glob EXIT_OK: int = 0,
     EXIT_FAILURE: int = 1,
     EXIT_USAGE: int = 2,
     EXIT_UNAVAILABLE: int = 3,
     EXIT_TIMEOUT: int = 4,
     EXIT_REJECTED: int = 5;

glob START_HINT: str = "hint: start the site with `jac run web`";

def warn(text: str);

def _suffix(detail: str) -> str;

def explain_bridge_error(e: BridgeError) -> int;

impl warn(text: str) {
    print(text, file=sys.stderr);
}

impl _suffix(detail: str) -> str {
    return " (" + detail + ")" if detail else "";
}

impl explain_bridge_error(e: BridgeError) -> int {
    where = e.app + "." + e.name;
    if isinstance(e, BridgeUnavailable) {
        warn("jacorg: " + where + " is not reachable" + _suffix(e.detail));
        warn(START_HINT);
        return EXIT_UNAVAILABLE;
    }
    if isinstance(e, BridgeTimeout) {
        warn("jacorg: " + where + " timed out" + _suffix(e.detail));
        return EXIT_TIMEOUT;
    }
    if isinstance(e, BridgeRejected) {
        warn("jacorg: " + where + " rejected the call" + _suffix(e.detail));
        warn("hint: the site wants a signed-in identity for this command");
        return EXIT_REJECTED;
    }
    warn("jacorg: " + where + " failed" + _suffix(e.detail));
    return EXIT_FAILURE;
}

def render_status(st: DocsStatus) -> str;

async def run_docs(action: str) -> int;

impl render_status(st: DocsStatus) -> str {
    if not st.ready {
        return "docs: the graph is empty, the web app has not ingested a corpus yet";
    }
    lines: list[str] = [
        "docs: ready · latest " + st.latest_label + " · built " + st.built_at
    ];
    for v in st.versions {
        lines.append(
            "  "
                + v.label
                + "  jac "
                + v.jac_version
                + "  "
                + str(v.pages)
                + " pages  fetched "
                + v.fetched_at
        );
    }
    return "\n".join(lines);
}

impl run_docs(action: str) -> int {
    try {
        if action == "sync" {
            await docs_sync_tick();
            print(
                "docs sync: the web app checked its graph against the bundled corpus"
            );
        }
        print(render_status(await docs_status()));
        return EXIT_OK;
    } except BridgeError as e {
        return explain_bridge_error(e);
    }
}

obj FeedLine {
    has author: str = "",
        content: str = "",
        created_at: str = "",
        likes: int = 0,
        comments: int = 0;
}


def render_line(line: FeedLine) -> str;

async def run_feed(limit: int, query: str) -> int;

async def run_post(text: str) -> int;

impl render_line(line: FeedLine) -> str {
    stamp = line.created_at[:19].replace("T", " ");
    head = "@" + (line.author or "someone") + "  " + stamp;
    tail = str(line.likes) + " likes · " + str(line.comments) + " comments";
    return head + "  ·  " + tail + "\n    " + line.content;
}

impl run_feed(limit: int, query: str) -> int {
    try {
        res = await load_feed(search_query=query);
        rows = res.reports[0] if res.reports else [];
        if not rows {
            scope = " for \"" + query + "\"" if query else "";
            print(
                "your feed is empty"
                    + scope
                    + "; post something: jacorg post \"hello from the cli\""
            );
            return EXIT_OK;
        }
        for raw in rows[:limit] {
            print(
                render_line(
                    FeedLine(
                        author=raw.author_username,
                        content=raw.content,
                        created_at=raw.created_at,
                        likes=len(raw.likes),
                        comments=len(raw.comments)
                    )
                )
            );
        }
        if len(rows) > limit {
            print("... " + str(len(rows) - limit) + " more; raise --limit to see them");
        }
        return EXIT_OK;
    } except BridgeError as e {
        return explain_bridge_error(e);
    }
}

impl run_post(text: str) -> int {
    body = text.strip();
    if not body {
        warn("jacorg post: nothing to post");
        return EXIT_USAGE;
    }
    try {
        made = await create_tweet(content=body);
        posted = made.reports;
        if posted {
            tweet = posted[0];
            if isinstance(tweet, PostingDenied) {
                warn(tweet.message);
                return EXIT_REJECTED;
            }
            print(
                "posted as @" + (tweet.author_username or "you") + ": " + tweet.content
            );
        } else {
            print(
                "posted nothing: the site found no profile for this identity "
                    + "(open /jacyac once to create one)"
            );
        }
        return EXIT_OK;
    } except BridgeError as e {
        return explain_bridge_error(e);
    }
}

glob PROG: str = "jacorg",
     DEFAULT_LIMIT: int = 20;

obj Invocation {
    has command: str = "",
        action: str = "",
        limit: int = DEFAULT_LIMIT,
        query: str = "",
        text: str = "";
}

def build_parser -> argparse.ArgumentParser;

def parse_args(argv: list[str]) -> Invocation;

async def dispatch(inv: Invocation) -> int;

async def main(argv: list[str]) -> int;

with entry:__main__ {
    sys.`exit(asyncio.run(main(sys.argv[1:])));
}

impl build_parser -> argparse.ArgumentParser {
    parser = argparse.ArgumentParser(
        prog=PROG,
        description="The command-line face of jaclang.org. "
        "Every command talks to a running site."
    );
    commands = parser.add_subparsers(
        dest="command", metavar="<command>", required=True
    );
    docs = commands.add_parser("docs", help="the docs graph of a running site");
    docs.add_argument(
        "action",
        choices=["sync", "status"],
        help="sync: ask the site to ingest its bundled docs; status: what the graph holds"
    );
    feed = commands.add_parser(
        "feed", help="read your JacYac feed from a running site"
    );
    feed.add_argument(
        "--limit",
        `type=int,
        `default=DEFAULT_LIMIT,
        help="how many tweets to show (default " + str(DEFAULT_LIMIT) + ")"
    );
    feed.add_argument(
        "--search", dest="query", `default="", help="only tweets containing this text"
    );
    post = commands.add_parser("post", help="post to JacYac through a running site");
    post.add_argument("text", help="what to say");
    return parser;
}

impl parse_args(argv: list[str]) -> Invocation {
    parser = build_parser();
    ns = parser.parse_args(argv);
    inv = Invocation(
        command=str(getattr(ns, "command", "") or ""),
        action=str(getattr(ns, "action", "") or ""),
        limit=int(getattr(ns, "limit", DEFAULT_LIMIT)),
        query=str(getattr(ns, "query", "") or ""),
        text=str(getattr(ns, "text", "") or "")
    );
    if inv.limit < 1 {
        parser.error("--limit must be at least 1");
    }
    return inv;
}

impl dispatch(inv: Invocation) -> int {
    if inv.command == "docs" {
        return await run_docs(inv.action);
    }
    if inv.command == "feed" {
        return await run_feed(inv.limit, inv.query);
    }
    if inv.command == "post" {
        return await run_post(inv.text);
    }
    warn("jacorg: unknown command " + inv.command);
    return EXIT_USAGE;
}

impl main(argv: list[str]) -> int {
    return await dispatch(parse_args(argv));
}
