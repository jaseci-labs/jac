import from core.social_graph { create_tweet, load_feed }
import from jaclang.server.bridge { BridgeError }
import from .common {
    EXIT_OK,
    EXIT_USAGE,
    explain_bridge_error,
    list_field,
    str_field,
    warn
}

obj FeedLine {
    has author: str = "",
        content: str = "",
        created_at: str = "",
        likes: int = 0,
        comments: int = 0;
}

def feed_line(raw: object) -> FeedLine {
    return FeedLine(
        author=str_field(raw, "author_username"),
        content=str_field(raw, "content"),
        created_at=str_field(raw, "created_at"),
        likes=len(list_field(raw, "likes")),
        comments=len(list_field(raw, "comments"))
    );
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
            print(render_line(feed_line(raw)));
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
        posted = list_field(made, "reports");
        if posted {
            line = feed_line(posted[0]);
            print("posted as @" + (line.author or "you") + ": " + line.content);
        } else {
            print(
                "posted nothing: the site found no profile for this identity "
                    + "(open /socialize once to create one)"
            );
        }
        return EXIT_OK;
    } except BridgeError as e {
        return explain_bridge_error(e);
    }
}
