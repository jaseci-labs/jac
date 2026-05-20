"""The `expr as Type` cast: re-types an Any source into a declared concrete type.

Without the cast, `feedResult.reports[0]` is `Any` (Walker.reports is list[Any])
and assigning it into a declared `list[TweetView]` / `TweetView` raises E1001
under the strict-gradual rule. The `as` cast makes the re-type explicit.
"""

obj TweetView {
    has id: str;
}

walker load_feed {
    has search_query: str = "";
}

with entry {
    feedResult = root spawn load_feed(search_query="");

    # Cast of a whole ternary result (parenthesized).
    tweets: list[TweetView] = [];
    tweets = (feedResult.reports[0] if feedResult.reports else []) as list[TweetView];

    # Cast of a plain Any attribute access.
    one: TweetView = feedResult.reports[0] as TweetView;

    # Cast of a variable holding Any.
    raw = feedResult.reports[0];
    two: TweetView = raw as TweetView;
}
