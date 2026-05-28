"""Tweet card component for Little X."""

import from "lucide-react" { Heart, MessageCircle, Trash2, Repeat2 }
sv import from ..server { TweetView }

def:pub TweetCard(
    tweet: TweetView,
    myUsername: str,
    onLike: Callable[[str], None],
    onComment: Callable[[str, str], None],
    onDelete: Callable[[str], None],
    onRepost: Callable[[str, str, str], None],
) -> JsxElement {
    has showComments: bool = False,
        commentText: str = "";

    is_liked = myUsername in tweet.likes;
    like_count = str(len(tweet.likes));
    comment_count = str(len(tweet.comments));
    author_avatar = "https://i.pravatar.cc/150?u=fake@" + tweet.author_username;

    raw_name = tweet.author_username or "unknown";
    display_name = raw_name.split("@")[0] if "@" in raw_name else raw_name;

    diff_ms = Date.now() - new(Date, tweet.created_at).getTime()
        if tweet.created_at
        else 0;
    diff_min = int(diff_ms / 60000);
    diff_hr = int(diff_min / 60);
    diff_day = int(diff_hr / 24);
    date_str = (
        "now"
            if diff_min < 1
            else (
                str(diff_min) + "m"
                    if diff_hr < 1
                    else (
                        str(diff_hr) + "h"
                            if diff_day < 1
                            else (
                                str(diff_day) + "d"
                                    if diff_day < 30
                                    else tweet.created_at[0:10]
                            )
                    )
            )
    )
        if tweet.created_at
        else "";

    return
        <div className="lx-tweet">
            <img className="lx-avatar" src={author_avatar} alt={tweet.author_username}/>
            <div className="lx-tweet-body">
                <div className="lx-tweet-header">
                    <span className="lx-tweet-name">{display_name}</span>
                    <span className="lx-tweet-handle">{"@" + display_name}</span>
                    <span className="lx-tweet-dot">·</span>
                    <span className="lx-tweet-time">{date_str}</span>
                </div>
                <div className="lx-tweet-text">{tweet.content}</div>
                <div className="lx-tweet-actions">
                    <button
                        className="lx-act-btn lx-act-comment"
                        onClick={lambda { showComments = not showComments; }}
                    >
                        <MessageCircle size={16}/>
                        <span>{comment_count}</span>
                    </button>
                    <button
                        className="lx-act-btn lx-act-repost"
                        onClick={lambda { onRepost(
                            tweet.id, tweet.content, tweet.author_username
                        ); }}
                        title="Repost"
                    >
                        <Repeat2 size={16}/>
                    </button>
                    <button
                        className={"lx-act-btn lx-act-liked"
                            if is_liked
                            else "lx-act-btn lx-act-like"}
                        onClick={lambda { onLike(tweet.id); }}
                    >
                        <Heart size={16}/>
                        <span>{like_count}</span>
                    </button>
                    {if tweet.is_mine {
                        <button
                            className="lx-act-btn lx-act-delete"
                            onClick={lambda { if confirm(
                                "Delete this post? This cannot be undone."
                            ) {
                                onDelete(tweet.id);
                            }}}
                        >
                            <Trash2 size={16}/>
                        </button>
                    }}
                </div>
                {if showComments {
                    <div className="lx-comments-section">
                        {for c in tweet.comments {
                            <div className="lx-comment-item" key={c["created_at"]}>
                                <img
                                    className="lx-avatar-sm"
                                    src={"https://i.pravatar.cc/150?u=fake@" + c[
                                        "username"
                                    ]}
                                    alt={c["username"]}
                                />
                                <div>
                                    <div className="lx-comment-meta">
                                        <strong>{c["username"]}</strong>
                                    </div>
                                    <div className="lx-comment-text">
                                        {c["content"]}
                                    </div>
                                </div>
                            </div>
                        }}
                        <div className="lx-comment-form">
                            <input
                                className="lx-comment-input"
                                placeholder="Reply..."
                                value={commentText}
                                onChange={lambda e: ChangeEvent { commentText = e.target.value; }}
                                onKeyDown={lambda e: KeyboardEvent { if e.key == "Enter"
                                and commentText.strip() {
                                    onComment(tweet.id, commentText);
                                    commentText = "";
                                }}}
                            />
                            <button
                                className="lx-comment-submit"
                                onClick={lambda { if commentText.strip() {
                                    onComment(tweet.id, commentText);
                                    commentText = "";
                                }}}
                            >
                                Reply
                            </button>
                        </div>
                    </div>
                }}
            </div>
        </div>;
}
