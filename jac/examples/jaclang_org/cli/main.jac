import argparse;
import asyncio;
import sys;
import from .commands.common { EXIT_USAGE, warn }
import from .commands.docs { run_docs }
import from .commands.feed { run_feed, run_post }
import from .commands.score { run_score }

glob PROG: str = "jacorg",
     DEFAULT_LIMIT: int = 20;

obj Invocation {
    has command: str = "",
        action: str = "",
        repo: str = "",
        as_json: bool = False,
        limit: int = DEFAULT_LIMIT,
        query: str = "",
        text: str = "";
}

def build_parser -> argparse.ArgumentParser {
    parser = argparse.ArgumentParser(
        prog=PROG,
        description="The command-line face of jaclang.org. "
        "`score` runs offline; the rest talk to a running site."
    );
    commands = parser.add_subparsers(
        dest="command", metavar="<command>", required=True
    );
    scorer = commands.add_parser(
        "score", help="score a GitHub repo against the ninja rubric, offline"
    );
    scorer.add_argument("repo", help="owner/name or a github.com URL");
    scorer.add_argument(
        "--json",
        dest="as_json",
        action="store_true",
        help="print the breakdown as JSON"
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

def parse_args(argv: list[str]) -> Invocation {
    parser = build_parser();
    ns = parser.parse_args(argv);
    inv = Invocation(
        command=str(getattr(ns, "command", "") or ""),
        action=str(getattr(ns, "action", "") or ""),
        repo=str(getattr(ns, "repo", "") or ""),
        as_json=bool(getattr(ns, "as_json", False)),
        limit=int(getattr(ns, "limit", DEFAULT_LIMIT)),
        query=str(getattr(ns, "query", "") or ""),
        text=str(getattr(ns, "text", "") or "")
    );
    if inv.limit < 1 {
        parser.error("--limit must be at least 1");
    }
    return inv;
}

async def dispatch(inv: Invocation) -> int {
    if inv.command == "score" {
        return run_score(inv.repo, inv.as_json);
    }
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

async def main(argv: list[str]) -> int {
    return await dispatch(parse_args(argv));
}

with entry:__main__ {
    sys.`exit(asyncio.run(main(sys.argv[1:])));
}
