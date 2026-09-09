import from core.social_graph { create_tweet, load_feed }
import from core.jacyac.limits { PostingDenied }
import from jaclang.server.bridge { BridgeError }
import from .common { EXIT_OK, EXIT_USAGE, EXIT_REJECTED, explain_bridge_error, warn }

obj FeedLine {
    has author: str = "",
        content: str = "",
        created_at: str = "",
        likes: int = 0,
        comments: int = 0;
}


def render_line(line: FeedLine) -> str {
    stamp = line.created_at[:19].replace("T", " ");
    head = "@" + (line.author or "someone") + "  " + stamp;
    tail = str(line.likes) + " likes · " + str(line.comments) + " comments";
    return head + "  ·  " + tail + "\n    " + line.content;
}

async def run_feed(limit: int, query: str) -> int {
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

async def run_post(text: str) -> int {
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
