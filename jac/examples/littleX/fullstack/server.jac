"""Little X - Social graph backend over an object-spatial user graph."""

import datetime;

def _now -> str {
    return datetime.datetime.utcnow().isoformat() + "Z";
}

# --- Graph archetypes: the persisted social graph ---
node Profile {
    has username: str = "",
        bio: str = "",
        created_at: str = "";
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

edge Follow {}
edge Post {}
edge Member {}
edge ChannelPost {}

# --- View models: the typed contract returned to the client ---
obj UserView {
    has id: str,
        username: str,
        bio: str = "";
}

obj TweetView {
    has id: str,
        content: str,
        author_username: str,
        created_at: str,
        likes: list[str],
        comments: list[dict[str, str]],
        is_mine: bool = False;
}

obj ProfileView {
    has id: str,
        username: str,
        bio: str,
        followers: list[UserView],
        following: list[UserView],
        tweets: list[TweetView];
}

obj ChannelView {
    has id: str,
        name: str,
        description: str,
        creator_username: str,
        created_at: str,
        member_count: int,
        is_member: bool,
        posts: list[TweetView] = [];
}

obj TrendingTag {
    has tag: str,
        count: int;
}

# --- View builders: turn graph nodes into view models ---
def _user_view(p: Profile) -> UserView {
    return UserView(id=jid(p), username=p.username, bio=p.bio);
}

def _tweet_view(t: Tweet, is_mine: bool) -> TweetView {
    return TweetView(
        id=jid(t),
        content=t.content,
        author_username=t.author_username,
        created_at=t.created_at,
        likes=t.likes,
        comments=t.comments,
        is_mine=is_mine
    );
}

# Sort keys -- typed so the type checker can resolve the comparison.
def _tweet_order(t: TweetView) -> str {
    return t.created_at;
}

def _channel_order(c: ChannelView) -> str {
    return c.created_at;
}

def _tag_order(t: TrendingTag) -> int {
    return t.count;
}

# Build the full ProfileView for a profile node -- shared by the
# `setup_profile` and `get_profile` walkers so both return the same type.
def _profile_view(me: Profile) -> ProfileView {
    my_id = jid(me);
    followers: list[UserView] = [];
    following: list[UserView] = [];
    for r in allroots() {
        for other in [r-->[?:Profile]] {
            if jid(other) != my_id {
                if [edge other->:Follow:->me] {
                    followers.append(_user_view(other));
                }
                if [edge me->:Follow:->other] {
                    following.append(_user_view(other));
                }
            }
        }
    }

    tweets: list[TweetView] = [_tweet_view(t, True) for t in [me-->[?:Tweet]]];
    tweets.sort(key=_tweet_order, reverse=True);

    return ProfileView(
        id=my_id,
        username=me.username,
        bio=me.bio,
        followers=followers,
        following=following,
        tweets=tweets
    );
}

# --- Walkers: object-spatial agents the client spawns ---
walker setup_profile {
    has username: str = "",
        bio: str = "",
        reports: list[ProfileView] = [];

    can run with Root entry {
        profiles = [-->[?:Profile]];
        if not profiles {
            new_profile = here ++> Profile(
                username=self.username, bio=self.bio, created_at=_now()
            );
            grant(new_profile[0], level=ConnectPerm);
            report _profile_view(new_profile[0]);
        } else {
            profile = profiles[0];
            if self.username {
                profile.username = self.username;
            }
            if self.bio {
                profile.bio = self.bio;
            }
            report _profile_view(profile);
        }
    }
}

walker get_profile {
    has reports: list[ProfileView] = [];

    can run with Root entry {
        profiles = [-->[?:Profile]];
        if not profiles {
            # No profile yet: report nothing so the client keeps its
            # current `myProfile` instead of receiving an error dict.
            disengage;
        }
        report _profile_view(profiles[0]);
    }
}

walker:pub get_all_profiles {
    has reports: list[list[UserView]] = [];

    can run with Root entry {
        results: list[UserView] = [];
        for r in allroots() {
            for prof in [r-->[?:Profile]] {
                results.append(_user_view(prof));
            }
        }
        report results;
    }
}

walker follow_user {
    has target_id: str;

    can run with Root entry {
        my_profiles = [-->[?:Profile]];
        if not my_profiles {
            report {"error": "No profile"};
            disengage;
        }
        my_profile = my_profiles[0];
        for r in allroots() {
            for target in [r-->[?:Profile]] {
                if jid(target) == self.target_id {
                    my_profile +>: Follow() :+> target;
                    report {"success": True};
                    disengage;
                }
            }
        }
        report {"error": "User not found"};
    }
}

walker unfollow_user {
    has target_id: str;

    can run with Root entry {
        my_profiles = [-->[?:Profile]];
        if not my_profiles {
            report {"error": "No profile"};
            disengage;
        }
        my_profile = my_profiles[0];
        for r in allroots() {
            for target in [r-->[?:Profile]] {
                if jid(target) == self.target_id {
                    follow_edges = [edge my_profile->:Follow:->target];
                    if follow_edges {
                        del follow_edges[0];
                    }
                    report {"success": True};
                    disengage;
                }
            }
        }
        report {"error": "User not found"};
    }
}

walker create_tweet {
    has content: str;

    can run with Root entry {
        profiles = [-->[?:Profile]];
        if not profiles {
            report {"error": "No profile"};
            disengage;
        }
        profile = profiles[0];
        new_tweets = profile +>: Post() :+> Tweet(
            content=self.content,
            author_username=profile.username,
            created_at=_now(),
            likes=[],
            comments=[]
        );
        grant(new_tweets[0], level=WritePerm);
        report _tweet_view(new_tweets[0], True);
    }
}

walker delete_tweet {
    has tweet_id: str;

    can run with Root entry {
        profiles = [-->[?:Profile]];
        if not profiles {
            report {"error": "No profile"};
            disengage;
        }
        profile = profiles[0];
        for tweet in [profile-->[?:Tweet]] {
            if jid(tweet) == self.tweet_id {
                del tweet;
                report {"success": True};
                disengage;
            }
        }
        for channel in [profile-->[?:Channel]] {
            for tweet in [channel-->[?:Tweet]] {
                if jid(tweet) == self.tweet_id
                and tweet.author_username == profile.username {
                    del tweet;
                    report {"success": True};
                    disengage;
                }
            }
        }
        report {"error": "Tweet not found"};
    }
}

walker like_tweet {
    has tweet_id: str;

    can run with Root entry {
        my_profiles = [-->[?:Profile]];
        if not my_profiles {
            report {"error": "No profile"};
            disengage;
        }
        username = my_profiles[0].username;
        for r in allroots() {
            for prof in [r-->[?:Profile]] {
                for tweet in [prof-->[?:Tweet]] {
                    if jid(tweet) == self.tweet_id {
                        report _toggle_like(tweet, username);
                        disengage;
                    }
                }
                for channel in [prof-->[?:Channel]] {
                    for tweet in [channel-->[?:Tweet]] {
                        if jid(tweet) == self.tweet_id {
                            report _toggle_like(tweet, username);
                            disengage;
                        }
                    }
                }
            }
        }
        report {"error": "Tweet not found"};
    }
}

def _toggle_like(tweet: Tweet, username: str) -> dict[str, object] {
    if username in tweet.likes {
        tweet.likes = [
            u
            for u in tweet.likes
            if u != username
        ];
        return {"liked": False, "likes": tweet.likes};
    }
    tweet.likes = tweet.likes + [username];
    return {"liked": True, "likes": tweet.likes};
}

walker add_comment {
    has tweet_id: str,
        content: str;

    can run with Root entry {
        my_profiles = [-->[?:Profile]];
        if not my_profiles {
            report {"error": "No profile"};
            disengage;
        }
        username = my_profiles[0].username;
        for r in allroots() {
            for prof in [r-->[?:Profile]] {
                for tweet in [prof-->[?:Tweet]] {
                    if jid(tweet) == self.tweet_id {
                        report _add_comment(tweet, username, self.content);
                        disengage;
                    }
                }
                for channel in [prof-->[?:Channel]] {
                    for tweet in [channel-->[?:Tweet]] {
                        if jid(tweet) == self.tweet_id {
                            report _add_comment(tweet, username, self.content);
                            disengage;
                        }
                    }
                }
            }
        }
        report {"error": "Tweet not found"};
    }
}

def _add_comment(tweet: Tweet, username: str, content: str) -> dict[str, object] {
    comment = {"username": username, "content": content, "created_at": _now()};
    tweet.comments = tweet.comments + [comment];
    return {"success": True, "comment": comment};
}

walker get_trending {
    has reports: list[list[TrendingTag]] = [];

    can run with Root entry {
        tag_counts: dict[str, int] = {};
        for r in allroots() {
            for prof in [r-->[?:Profile]] {
                for tweet in [prof-->[?:Tweet]] {
                    for word in tweet.content.split() {
                        if word.startswith("#") and len(word) > 1 {
                            tag = word.lower().rstrip(".,!?;:");
                            if tag in tag_counts {
                                tag_counts[tag] += 1;
                            } else {
                                tag_counts[tag] = 1;
                            }
                        }
                    }
                }
            }
        }
        tags: list[TrendingTag] = [
            TrendingTag(tag=tag, count=tag_counts[tag]) for tag in tag_counts
        ];
        tags.sort(key=_tag_order, reverse=True);
        report tags[:8];
    }
}

walker load_feed {
    has search_query: str = "",
        reports: list[list[TweetView]] = [];

    can run with Root entry {
        profiles = [-->[?:Profile]];
        if not profiles {
            report [];
            disengage;
        }
        my_profile = profiles[0];
        feed: list[TweetView] = [];

        for tweet in [my_profile-->[?:Tweet]] {
            feed.append(_tweet_view(tweet, True));
        }
        for followed in [my_profile->:Follow:->[?:Profile]] {
            for tweet in [followed-->[?:Tweet]] {
                feed.append(_tweet_view(tweet, False));
            }
        }

        if self.search_query {
            q = self.search_query.lower().strip();
            feed = [
                t
                for t in feed
                if q in t.content.lower()
            ];
        }
        feed.sort(key=_tweet_order, reverse=True);
        report feed;
    }
}

walker create_channel {
    has name: str,
        description: str = "";

    can run with Root entry {
        profiles = [-->[?:Profile]];
        if not profiles {
            report {"error": "No profile"};
            disengage;
        }
        profile = profiles[0];
        new_channels = profile +>: Member() :+> Channel(
            name=self.name,
            description=self.description,
            creator_username=profile.username,
            created_at=_now()
        );
        ch = new_channels[0];
        grant(ch, level=ConnectPerm);
        report ChannelView(
            id=jid(ch),
            name=ch.name,
            description=ch.description,
            creator_username=ch.creator_username,
            created_at=ch.created_at,
            member_count=1,
            is_member=True
        );
    }
}

walker join_channel {
    has channel_id: str;

    can run with Root entry {
        profiles = [-->[?:Profile]];
        if not profiles {
            report {"error": "No profile"};
            disengage;
        }
        profile = profiles[0];
        for r in allroots() {
            for prof in [r-->[?:Profile]] {
                for ch in [prof-->[?:Channel]] {
                    if jid(ch) == self.channel_id {
                        if not [edge profile->:Member:->ch] {
                            profile +>: Member() :+> ch;
                        }
                        report {"success": True};
                        disengage;
                    }
                }
            }
        }
        report {"error": "Channel not found"};
    }
}

walker leave_channel {
    has channel_id: str;

    can run with Root entry {
        profiles = [-->[?:Profile]];
        if not profiles {
            report {"error": "No profile"};
            disengage;
        }
        profile = profiles[0];
        for ch in [profile-->[?:Channel]] {
            if jid(ch) == self.channel_id {
                member_edges = [edge profile->:Member:->ch];
                if member_edges {
                    del member_edges[0];
                }
                report {"success": True};
                disengage;
            }
        }
        report {"error": "Channel not found"};
    }
}

walker get_channels {
    has reports: list[list[ChannelView]] = [];

    can run with Root entry {
        my_profiles = [-->[?:Profile]];
        my_channel_ids: list[str] = [];
        if my_profiles {
            for ch in [my_profiles[0]-->[?:Channel]] {
                my_channel_ids.append(jid(ch));
            }
        }

        seen: dict[str, bool] = {};
        channels: list[ChannelView] = [];
        for r in allroots() {
            for prof in [r-->[?:Profile]] {
                for ch in [prof-->[?:Channel]] {
                    ch_id = jid(ch);
                    if ch_id not in seen {
                        seen[ch_id] = True;
                        channels.append(
                            ChannelView(
                                id=ch_id,
                                name=ch.name,
                                description=ch.description,
                                creator_username=ch.creator_username,
                                created_at=ch.created_at,
                                member_count=len([ch<-:Member:<-[?:Profile]]),
                                is_member=ch_id in my_channel_ids
                            )
                        );
                    }
                }
            }
        }
        channels.sort(key=_channel_order, reverse=True);
        report channels;
    }
}

walker get_channel_detail {
    has channel_id: str,
        reports: list[ChannelView] = [];

    can run with Root entry {
        my_profiles = [-->[?:Profile]];
        my_username = my_profiles[0].username if my_profiles else "";

        for r in allroots() {
            for prof in [r-->[?:Profile]] {
                for ch in [prof-->[?:Channel]] {
                    if jid(ch) == self.channel_id {
                        is_member = False;
                        if my_profiles and [edge my_profiles[0]->:Member:->ch] {
                            is_member = True;
                        }
                        posts: list[TweetView] = [
                            _tweet_view(t, t.author_username == my_username)
                            for t in [ch-->[?:Tweet]]
                        ];
                        posts.sort(key=_tweet_order, reverse=True);
                        report ChannelView(
                            id=jid(ch),
                            name=ch.name,
                            description=ch.description,
                            creator_username=ch.creator_username,
                            created_at=ch.created_at,
                            member_count=len([ch<-:Member:<-[?:Profile]]),
                            is_member=is_member,
                            posts=posts
                        );
                        disengage;
                    }
                }
            }
        }
        # Channel not found: report nothing so the client sees an empty
        # `reports` list and leaves the current view untouched.
    }
}

walker create_channel_tweet {
    has channel_id: str,
        content: str;

    can run with Root entry {
        profiles = [-->[?:Profile]];
        if not profiles {
            report {"error": "No profile"};
            disengage;
        }
        profile = profiles[0];
        for ch in [profile-->[?:Channel]] {
            if jid(ch) == self.channel_id {
                new_tweets = ch +>: ChannelPost() :+> Tweet(
                    content=self.content,
                    author_username=profile.username,
                    created_at=_now(),
                    likes=[],
                    comments=[]
                );
                grant(new_tweets[0], level=WritePerm);
                report _tweet_view(new_tweets[0], True);
                disengage;
            }
        }
        report {"error": "Not a member of this channel"};
    }
}
