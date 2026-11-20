obj ProfileBundle {
    has profile: Profile,
        followers: list[Profile],
        following: list[Profile],
        tweets: list[Tweet];
}

obj ChannelBundle {
    has channel: Channel,
        member_count: int,
        is_member: bool,
        posts: list[Tweet] = [];
}

obj TrendingTag {
    has tag: str,
        count: int;
}

obj FieldCheck {
    has ok: bool = True,
        error: str = "",
        value: str = "";
}

obj AvatarCheck {
    has ok: bool = False,
        error: str = "",
        mime: str = "",
        data: str = "";
}

obj ProfileResult {
    has ok: bool = False,
        error: str = "",
        bundle: ProfileBundle | None = None;
}

obj AvatarResult {
    has ok: bool = False,
        error: str = "",
        avatar_v: str = "",
        avatar_url: str = "";
}

node Profile {
    has username: str = "",
        display_name: str = "",
        bio: str = "",
        location: str = "",
        website: str = "",
        github: str = "",
        avatar_v: str = "",
        created_at: str = "";
}

node Avatar {
    has mime: str = "image/jpeg",
        data: str = "",
        updated_at: str = "";
}

node Tweet {
    has content: str = "",
        author_username: str = "",
        created_at: str = "",
        likes: list[str] = [],
        comments: list[dict[str, str]] = [];
}

node Channel {
    has name: str = "",
        description: str = "",
        creator_username: str = "",
        created_at: str = "";
}

obj PostingDenied {
    has message: str,
        retry_after_seconds: int;
}

"""What posting gives: the tweet made, or why it wasn't (`denied`)."""
obj Posted {
    has tweet: Tweet | None = None,
        denied: PostingDenied | None = None;
}

"""What a like leaves: whether its caller likes the tweet now, and who does."""
obj Liked {
    has liked: bool,
        likes: list[str];
}

"""What commenting gives: the comment added, or why it wasn't (`denied`)."""
obj Commented {
    has comment: dict[str, str] = {},
        denied: PostingDenied | None = None;
}
