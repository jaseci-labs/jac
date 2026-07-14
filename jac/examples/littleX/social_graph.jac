"""Little X - Social graph backend in idiomatic object-spatial style.

The graph holds the data: `Profile` / `Tweet` / `Channel` nodes wired by
typed edges. Walkers are the mobile agents the client spawns - each one
declares where it starts (`with Root entry`) and what to do at every node
type it lands on (`with Tweet entry`, ...). Traversal is `visit`, never a
hand-rolled loop, and shared fan-out lives in small base walkers.
"""

import datetime;

def _now -> str {
    return datetime.datetime.now(datetime.UTC).replace(tzinfo=None).isoformat() + "Z";
}

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

# --- Edges: the relationships in the social graph ---
edge Follow {}
edge Post {}
edge Member {}
edge ChannelPost {}

# --- Graph nodes: data, plus the methods that present it as a view.
#     A node knows how to describe itself; walkers decide when to ask. ---
node Profile {
    has username: str = "",
        bio: str = "",
        created_at: str = "";

    def to_user_view -> UserView {
        return UserView(id=jid(self), username=self.username, bio=self.bio);
    }

    # Followers / following fall straight out of the edges - no graph scan.
    def to_profile_view -> ProfileView {
        followers = [p.to_user_view() for p in [self<-:Follow:<-[?:Profile]]];
        following = [p.to_user_view() for p in [self->:Follow:->[?:Profile]]];
        tweets = [t.to_view() for t in [self-->[?:Tweet]]];
        tweets.sort(key=lambda (t: TweetView) { t.created_at; }, reverse=True);
        return ProfileView(
            id=jid(self),
            username=self.username,
            bio=self.bio,
            followers=followers,
            following=following,
            tweets=tweets
        );
    }
}

node Tweet {
    has content: str = "",
        author_username: str = "",
        created_at: str = "",
        likes: list[str] = [],
        comments: list[dict[str, str]] = [];

    def to_view -> TweetView {
        mine = [root-->[?:Profile]];
        is_mine: bool = len(mine) > 0 and self.author_username == mine[0].username;
        return TweetView(
            id=jid(self),
            content=self.content,
            author_username=self.author_username,
            created_at=self.created_at,
            likes=self.likes,
            comments=self.comments,
            is_mine=is_mine
        );
    }
}

node Channel {
    has name: str = "",
        description: str = "",
        creator_username: str = "",
        created_at: str = "";

    def to_view(with_posts: bool) -> ChannelView {
        mine = [root-->[?:Profile]];
        is_member: bool = len(mine) > 0 and len([edge mine[0]->:Member:->self]) > 0;
        posts: list[TweetView] = [];
        if with_posts {
            posts = [t.to_view() for t in [self-->[?:Tweet]]];
            posts.sort(key=lambda (t: TweetView) { t.created_at; }, reverse=True);
        }
        return ChannelView(
            id=jid(self),
            name=self.name,
            description=self.description,
            creator_username=self.creator_username,
            created_at=self.created_at,
            member_count=len([self<-:Member:<-[?:Profile]]),
            is_member=is_member,
            posts=posts
        );
    }
}

# --- Profile walkers: spawn at the caller's root, act on their profile ---
walker setup_profile {
    has username: str = "",
        bio: str = "",
        reports: list[ProfileView] = [];

    can run with Root entry {
        # The `else` fires when `visit` enqueues nothing - i.e. no profile
        # exists yet - so we create one and walk into it instead.
        visit [-->[?:Profile]] else {
            fresh = here ++> Profile(created_at=_now());
            grant(fresh, level=ConnectPerm);
            visit fresh;
        }
    }

    can apply with Profile entry {
        if self.username {
            here.username = self.username;
        }
        if self.bio {
            here.bio = self.bio;
        }
        report here.to_profile_view();
    }
}

walker get_profile {
    has reports: list[ProfileView] = [];

    can run with Root entry {
        visit [-->[?:Profile]];
    }

    can give with Profile entry {
        report here.to_profile_view();
    }
}

# --- Accumulator walkers: fan out, gather at each node, report once at exit ---
walker:pub get_all_profiles {
    has results: list[UserView] = [],
        reports: list[list[UserView]] = [];

    can run with Root entry {
        for r in allroots() {
            visit [r-->[?:Profile]];
        }
    }

    can gather with Profile entry {
        self.results.append(here.to_user_view());
    }

    can deliver with Root exit {
        report self.results;
    }
}

walker get_trending {
    # `allroots()` can surface the same Tweet through more than one
    # path (e.g. via the system root and the user's own root), so a
    # bare per-visit tally would double-count. Dedupe by tweet jid.
    has counts: dict[str, int] = {},
        seen: dict[str, bool] = {},
        reports: list[list[TrendingTag]] = [];

    can run with Root entry {
        for r in allroots() {
            visit [r-->[?:Profile]-->[?:Tweet]];
        }
    }

    can tally with Tweet entry {
        tid = jid(here);
        if tid in self.seen {
            return;
        }
        self.seen[tid] = True;
        for word in here.content.split() {
            if word.startswith("#") and len(word) > 1 {
                tag = word.lower().rstrip(".,!?;:");
                self.counts[tag] = self.counts.get(tag, 0) + 1;
            }
        }
    }

    can deliver with Root exit {
        tags = [TrendingTag(tag=t, count=self.counts[t]) for t in self.counts];
        tags.sort(key=lambda (x: TrendingTag) { x.count; }, reverse=True);
        report tags[:8];
    }
}

walker load_feed {
    has search_query: str = "",
        feed: list[TweetView] = [],
        reports: list[list[TweetView]] = [];

    can run with Root entry {
        mine = [-->[?:Profile]];
        if mine {
            me = mine[0];
            visit [me-->[?:Tweet]];
            visit [me->:Follow:->[?:Profile]-->[?:Tweet]];
        }
    }

    can gather with Tweet entry {
        self.feed.append(here.to_view());
    }

    can deliver with Root exit {
        result = self.feed;
        if self.search_query {
            q = self.search_query.lower().strip();
            result = [
                t
                for t in result
                if q in t.content.lower()
            ];
        }
        result.sort(key=lambda (t: TweetView) { t.created_at; }, reverse=True);
        report result;
    }
}

walker get_channels {
    has seen: dict[str, bool] = {},
        results: list[ChannelView] = [],
        reports: list[list[ChannelView]] = [];

    can run with Root entry {
        for r in allroots() {
            visit [r-->[?:Profile]-->[?:Channel]];
        }
    }

    # A channel links to every member, so it can be reached more than once.
    can gather with Channel entry {
        cid = jid(here);
        if cid not in self.seen {
            self.seen[cid] = True;
            self.results.append(here.to_view(False));
        }
    }

    can deliver with Root exit {
        self.results.sort(key=lambda (c: ChannelView) { c.created_at; }, reverse=True);
        report self.results;
    }
}

# --- Create walkers: navigate to the caller's profile, then attach a node ---
walker create_tweet {
    has content: str;

    can run with Root entry {
        visit [-->[?:Profile]];
    }

    can make with Profile entry {
        new = here +>:Post():+> Tweet(
            content=self.content, author_username=here.username, created_at=_now()
        );
        grant(new, level=WritePerm);
        report new.to_view();
    }
}

walker create_channel {
    has name: str,
        description: str = "";

    can run with Root entry {
        visit [-->[?:Profile]];
    }

    can make with Profile entry {
        new = here +>:Member():+> Channel(
            name=self.name,
            description=self.description,
            creator_username=here.username,
            created_at=_now()
        );
        grant(new, level=ConnectPerm);
        report new.to_view(False);
    }
}

# --- Lookup base walkers: resolve the target node by jid via `& (id)`
#     and visit it directly. Action subclasses just react on entry. ---
walker find_profile {
    has target_id: str = "";

    can run with Root entry {
        if self.target_id {
            target = jobj(self.target_id);
            if isinstance(target, Profile) {
                visit [target];
            }
        }
    }
}

walker follow_user(find_profile) {
    can act with Profile entry {
        if jid(here) == self.target_id {
            me = [root-->[?:Profile]][0];
            me +>:Follow():+> here;
            report {"success": True};
            disengage;
        }
    }
}

walker unfollow_user(find_profile) {
    can act with Profile entry {
        if jid(here) == self.target_id {
            me = [root-->[?:Profile]][0];
            edges = [edge me->:Follow:->here];
            if edges {
                del edges[0];
            }
            report {"success": True};
            disengage;
        }
    }
}

# `actor` is resolved once on entry so Tweet abilities need no extra lookup.
walker find_tweet {
    has tweet_id: str = "",
        actor: str = "";

    can run with Root entry {
        mine = [-->[?:Profile]];
        if mine {
            self.actor = mine[0].username;
        }
        if self.tweet_id {
            target = jobj(self.tweet_id);
            if isinstance(target, Tweet) {
                visit [target];
            }
        }
    }
}

walker like_tweet(find_tweet) {
    can act with Tweet entry {
        if jid(here) == self.tweet_id {
            if self.actor in here.likes {
                here.likes = [
                    u
                    for u in here.likes
                    if u != self.actor
                ];
                report {"liked": False, "likes": here.likes};
            } else {
                here.likes = here.likes + [self.actor];
                report {"liked": True, "likes": here.likes};
            }
            disengage;
        }
    }
}

walker delete_tweet(find_tweet) {
    can act with Tweet entry {
        if jid(here) == self.tweet_id and here.author_username == self.actor {
            del here;
            report {"success": True};
            disengage;
        }
    }
}

walker add_comment(find_tweet) {
    has content: str = "";

    can act with Tweet entry {
        if jid(here) == self.tweet_id {
            comment = {
                "username": self.actor,
                "content": self.content,
                "created_at": _now()
            };
            here.comments = here.comments + [comment];
            report {"success": True, "comment": comment};
            disengage;
        }
    }
}

walker find_channel {
    has channel_id: str = "";

    can run with Root entry {
        if self.channel_id {
            target = jobj(self.channel_id);
            if isinstance(target, Channel) {
                visit [target];
            }
        }
    }
}

walker join_channel(find_channel) {
    can act with Channel entry {
        if jid(here) == self.channel_id {
            me = [root-->[?:Profile]][0];
            if not [edge me->:Member:->here] {
                me +>:Member():+> here;
            }
            report {"success": True};
            disengage;
        }
    }
}

walker leave_channel(find_channel) {
    can act with Channel entry {
        if jid(here) == self.channel_id {
            me = [root-->[?:Profile]][0];
            edges = [edge me->:Member:->here];
            if edges {
                del edges[0];
            }
            report {"success": True};
            disengage;
        }
    }
}

walker get_channel_detail(find_channel) {
    has reports: list[ChannelView] = [];

    can act with Channel entry {
        if jid(here) == self.channel_id {
            report here.to_view(True);
            disengage;
        }
    }
}

walker create_channel_tweet(find_channel) {
    has content: str = "";

    can act with Channel entry {
        if jid(here) == self.channel_id {
            me = [root-->[?:Profile]][0];
            if [edge me->:Member:->here] {
                new = here +>:ChannelPost():+> Tweet(
                    content=self.content, author_username=me.username, created_at=_now()
                );
                grant(new, level=WritePerm);
                report new.to_view();
            }
            disengage;
        }
    }
}
