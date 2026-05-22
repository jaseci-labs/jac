"""Rec 1 — for-loop slot whose body emits multiple keyless JSX siblings.

ViewLowerPass should detect this shape and wrap each iteration in a
synthesized `<React.Fragment key={jid(tweet)}>...</>` so that one
iteration is one keyed unit in the React diff, instead of three keyless
siblings that all share the same diff bucket.
"""

obj Tweet {
    has author: str,
        body: str;
}

def:pub TweetRow(tweet: Tweet) -> JsxElement {
    return
        <div class="row">
            <h3>{tweet.author}</h3>
            <p>{tweet.body}</p>
            <button>like</button>
        </div>;
}

"""A list of tweets where each iteration emits three top-level keyless
JSX statements. Without auto-fragmenting, React diffs them as one flat
keyless list and loses iteration identity on reorder."""
def:pub TweetList(tweets: list[Tweet]) -> JsxElement {
    return
        <section class="feed">
            {for tweet in tweets {
                <h3>{tweet.author}</h3>
                <p>{tweet.body}</p>
                <button>like</button>
            }}
        </section>;
}
