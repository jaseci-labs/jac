impl warn(text: str) {
    print(text, file=sys.stderr);
}

impl _suffix(detail: str) -> str {
    return " (" + detail + ")" if detail else "";
}

impl explain_bridge_error(e: RemoteError) -> int {
    where = e.endpoint;
    if isinstance(e, RemoteUnavailable) {
        warn("jacorg: " + where + " is not reachable" + _suffix(e.detail));
        warn(START_HINT);
        return EXIT_UNAVAILABLE;
    }
    if isinstance(e, RemoteTimeout) {
        warn("jacorg: " + where + " timed out" + _suffix(e.detail));
        return EXIT_TIMEOUT;
    }
    if isinstance(e, RemoteRejected) {
        warn("jacorg: " + where + " rejected the call" + _suffix(e.detail));
        warn("hint: the site wants a signed-in identity for this command");
        return EXIT_REJECTED;
    }
    warn("jacorg: " + where + " failed" + _suffix(e.detail));
    return EXIT_FAILURE;
}

impl render_status(st: DocsStatus) -> str {
    if not st.ready {
        return "docs: the graph is empty, the web app has not ingested a corpus yet";
    }
    lines: list[str] = ["docs: ready · latest " + st.latest_label + " · built " + st.built_at];
    for v in st.versions {
        lines.append(
            "  "
                + v.label
                + "  jac "
                + v.version
                + "  "
                + str(v.pages)
                + " pages  fetched "
                + v.fetched_at,
        );
    }
    return "\n".join(lines);
}

impl run_docs(action: str) -> int {
    try {
        if action == "sync" {
            docs_sync_tick();
            print("docs sync: the web app checked its graph against the bundled corpus");
        }
        print(render_status(docs_status()));
        return EXIT_OK;
    } except RemoteError as e {
        return explain_bridge_error(e);
    }
}

impl render_line(line: FeedLine) -> str {
    stamp = line.created_at[:19].replace("T", " ");
    head = "@" + (line.author or "someone") + "  " + stamp;
    tail = str(line.likes) + " likes · " + str(line.comments) + " comments";
    return head + "  ·  " + tail + "\n    " + line.content;
}

impl run_feed(limit: int, query: str) -> int {
    try {
        res = root spawn load_feed(search_query=query);
        rows: list[Tweet] = res.reports[0] if res.reports else [];
        if not rows {
            scope = " for \"" + query + "\"" if query else "";
            print(
                "your feed is empty"
                    + scope
                    + "; post something: jacorg post \"hello from the cli\"",
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
                        comments=len(raw.comments),
                    ),
                ),
            );
        }
        if len(rows) > limit {
            print("... " + str(len(rows) - limit) + " more; raise --limit to see them");
        }
        return EXIT_OK;
    } except RemoteError as e {
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
        made = root spawn create_tweet(content=body);
        posted = made.reports;
        if posted {
            denied = posted[0].denied;
            if denied is not None {
                warn(denied.message);
                return EXIT_REJECTED;
            }
            tweet = posted[0].tweet;
            if tweet is not None {
                print("posted as @" + (tweet.author_username or "you") + ": " + tweet.content);
            }
        } else {
            print(
                "posted nothing: the site found no profile for this identity "
                    + "(open /jacyac once to create one)",
            );
        }
        return EXIT_OK;
    } except RemoteError as e {
        return explain_bridge_error(e);
    }
}

impl parse_args(argv: list[str]) -> Parsed {
    inv = Invocation();
    if len(argv) == 0 {
        return Parsed(error="a command is needed: docs, feed or post");
    }
    if argv[0] in ["-h", "--help"] {
        return Parsed(show_help=True);
    }
    inv.command = argv[0];
    rest = argv[1:];
    if inv.command == "docs" {
        if len(rest) != 1 or rest[0] not in ["sync", "status"] {
            return Parsed(error="docs takes one of: sync, status");
        }
        inv.action = rest[0];
    } elif inv.command == "post" {
        if len(rest) != 1 {
            return Parsed(error="post takes what to say, as one argument");
        }
        inv.text = rest[0];
    } elif inv.command == "feed" {
        i = 0;
        while i < len(rest) {
            if rest[i] not in ["--limit", "--search"] or i + 1 >= len(rest) {
                return Parsed(error="feed takes --limit N and --search TEXT");
            }
            if rest[i] == "--search" {
                inv.query = rest[i + 1];
            } elif not rest[i + 1].isdigit() or int(rest[i + 1]) < 1 {
                return Parsed(error="--limit must be at least 1");
            } else {
                inv.limit = int(rest[i + 1]);
            }
            i += 2;
        }
    } else {
        return Parsed(error="no such command: " + inv.command);
    }
    return Parsed(inv=inv);
}

impl dispatch(inv: Invocation) -> int {
    if inv.command == "docs" {
        return run_docs(inv.action);
    }
    if inv.command == "feed" {
        return run_feed(inv.limit, inv.query);
    }
    if inv.command == "post" {
        return run_post(inv.text);
    }
    warn("jacorg: unknown command " + inv.command);
    return EXIT_USAGE;
}

impl main(argv: list[str]) -> int {
    parsed = parse_args(argv);
    if parsed.show_help {
        print(USAGE);
        return EXIT_OK;
    }
    if parsed.error != "" {
        warn(PROG + ": " + parsed.error);
        warn(USAGE);
        return EXIT_USAGE;
    }
    return dispatch(parsed.inv);
}
