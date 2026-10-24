import re;
import base64;
import datetime;
import os;

def _now -> str;

glob MAX_DISPLAY_NAME: int = 50,
     MAX_BIO: int = 280,
     MAX_LOCATION: int = 60,
     MAX_WEBSITE: int = 200,
     MAX_AVATAR_BYTES: int = 393216;

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

edge Follow: Profile --> Profile {}
edge Post: Profile --> Tweet {}
edge Member: Profile --> Channel {}
edge ChannelPost: Channel --> Tweet {}
edge HasAvatar: Profile --> Avatar {}

node NinjaclawDesk {
    has started_at: str = "",
        seen_until: str = "",
        recent_keys: dict[str, str] = {},
        pending: dict[str, str] = {},
        asked: dict[str, str] = {},
        recent_asks: dict[str, list[str]] = {};
}

glob NINJACLAW: str = "ninjaclaw",
     HELP_CHANNEL: str = "help",
     DESK_TICK_S: float = 15.0,
     ASKS_PER_HOUR: int = int(os.environ.get("NINJACLAW_ASKS_PER_HOUR", "3") or 3),
     SCAN_GRACE_S: float = 600.0,
     ASKED_LIMIT: int = 2000,
     MENTION_RE: str = r"(?<![\w@])@ninjaclaw\b";

def mentions_ninjaclaw(text: str) -> bool;

def strip_mention(text: str) -> str;

def ninjaclaw_profile -> Profile;

def help_channel(claw: Profile) -> Channel;

def live_tweets -> dict[str, Tweet];

def scan_floor(desk: NinjaclawDesk) -> str;

def desk_asks(
    desk: NinjaclawDesk, help: Channel, tweets: dict[str, Tweet]
) -> list[AskInput];

def throttled(desk: NinjaclawDesk, asker: str) -> bool;

def post_reply(tweet_id: str, reply: str) -> bool;

@schedule(trigger=ScheduleTrigger.STATIC, interval=DESK_TICK_S)
async walker:priv ninjaclaw_desk {
    async can run with Root entry;
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

    def avatar_url -> str;
    def to_bundle -> ProfileBundle;
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

    def to_bundle(with_posts: bool) -> ChannelBundle;
}

def:protect clean_github(raw: str) -> FieldCheck;

def:protect clean_website(raw: str) -> FieldCheck;

def:protect clean_text(raw: str, limit: int, label: str) -> FieldCheck;

def:protect decode_avatar(data_url: str) -> AvatarCheck;

def:protect find_profile_by_username(username: str) -> Profile | None;

walker:protect setup_profile {
    has username: str = "",
        bio: str = "",
        reports: list[ProfileBundle] = [];

    can run with Root entry;
    can apply with Profile entry;
}

walker:protect update_profile {
    has display_name: str = "",
        bio: str = "",
        location: str = "",
        website: str = "",
        github: str = "",
        reports: list[ProfileResult] = [];

    can run with Root entry;
    can apply with Profile entry;
}

walker:protect get_profile {
    has reports: list[ProfileBundle] = [];

    can run with Root entry;
    can give with Profile entry;
}

walker:pub get_user_profile {
    has username: str = "",
        reports: list[ProfileResult] = [];

    can run with Root entry;
}

walker:protect set_avatar {
    has data_url: str = "",
        reports: list[AvatarResult] = [];

    can run with Root entry;
    can apply with Profile entry;
}

walker:protect clear_avatar {
    has reports: list[AvatarResult] = [];

    can run with Root entry;
    can apply with Profile entry;
}

walker:pub get_avatars {
    has usernames: list[str] = [],
        found: dict[str, str] = {},
        reports: list[dict[str, str]] = [];

    can run with Root entry;
}

walker:pub get_all_profiles {
    has results: list[Profile] = [],
        reports: list[list[Profile]] = [];

    can run with Root entry;
    can gather with Profile entry;
    can deliver with Root exit;
}

walker:protect get_trending {
    has counts: dict[str, int] = {},
        seen: dict[str, bool] = {},
        reports: list[list[TrendingTag]] = [];

    can run with Root entry;
    can tally with Tweet entry;
    can deliver with Root exit;
}

walker:protect load_feed {
    has search_query: str = "",
        feed: list[Tweet] = [],
        reports: list[list[Tweet]] = [];

    can run with Root entry;
    can gather with Tweet entry;
    can deliver with Root exit;
}

walker:protect get_channels {
    has seen: dict[str, bool] = {},
        results: list[ChannelBundle] = [],
        reports: list[list[ChannelBundle]] = [];

    can run with Root entry;
    can gather with Channel entry;
    can deliver with Root exit;
}

walker:protect create_tweet {
    has content: str,
        reports: list[Tweet | PostingDenied] = [];

    can run with Root entry;
    can make with Profile entry;
}

walker:protect create_channel {
    has name: str,
        description: str = "";

    can run with Root entry;
    can make with Profile entry;
}

walker:protect find_profile {
    has target_id: str = "";

    can run with Root entry;
}

walker:protect follow_user(find_profile) {
    can act with Profile entry;
}

walker:protect unfollow_user(find_profile) {
    can act with Profile entry;
}

walker:protect find_tweet {
    has tweet_id: str = "",
        actor: str = "";

    can run with Root entry;
}

walker:protect like_tweet(find_tweet) {
    can act with Tweet entry;
}

walker:protect delete_tweet(find_tweet) {
    can act with Tweet entry;
}

walker:protect add_comment(find_tweet) {
    has content: str = "";

    can act with Tweet entry;
}

walker:protect find_channel {
    has channel_id: str = "";

    can run with Root entry;
}

walker:protect join_channel(find_channel) {
    can act with Channel entry;
}

walker:protect leave_channel(find_channel) {
    can act with Channel entry;
}

walker:protect get_channel_detail(find_channel) {
    has reports: list[ChannelBundle] = [];

    can act with Channel entry;
}

walker:protect create_channel_tweet(find_channel) {
    has content: str = "";

    can act with Channel entry;
}

impl _now -> str {
    return datetime.datetime.now(datetime.UTC).replace(tzinfo=None).isoformat() + "Z";
}

impl Profile.avatar_url -> str {
    av = [self->:HasAvatar:->[?:Avatar]];
    if not av {
        return "";
    }
    return "data:" + av[0].mime + ";base64," + av[0].data;
}

impl Profile.to_bundle -> ProfileBundle {
    tweets = [self-->[?:Tweet]];
    tweets.sort(key=lambda (t: Tweet) { t.created_at; }, reverse=True);
    return ProfileBundle(
        profile=self,
        followers=[self<-:Follow:<-[?:Profile]],
        following=[self->:Follow:->[?:Profile]],
        tweets=tweets
    );
}

impl Channel.to_bundle(with_posts: bool) -> ChannelBundle {
    mine = [root-->[?:Profile]];
    is_member: bool = len(mine) > 0 and len([edge mine[0]->:Member:->self]) > 0;
    posts: list[Tweet] = [];
    if with_posts {
        posts = [self-->[?:Tweet]];
        posts.sort(key=lambda (t: Tweet) { t.created_at; }, reverse=True);
    }
    return ChannelBundle(
        channel=self,
        member_count=len([self<-:Member:<-[?:Profile]]),
        is_member=is_member,
        posts=posts
    );
}

impl clean_github(raw: str) -> FieldCheck {
    v = raw.strip();
    if v == "" {
        return FieldCheck(value="");
    }
    m = re.`match(r"^(?:https?://)?(?:www\.)?github\.com/([A-Za-z0-9-]+)/?$", v);
    if m is not None {
        v = m.group(1) as str;
    }
    v = v.lstrip("@");
    if re.`match(r"^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$", v) is None {
        return FieldCheck(
            ok=False, error="GitHub handle can only contain letters, digits and hyphens"
        );
    }
    return FieldCheck(value=v);
}

impl clean_website(raw: str) -> FieldCheck {
    v = raw.strip();
    if v == "" {
        return FieldCheck(value="");
    }
    if re.`match(r"^https?://", v, re.IGNORECASE) is None {
        v = "https://" + v;
    }
    if len(v) > MAX_WEBSITE or re.`match(r"^https?://[^\s/$.?#][^\s]*$", v) is None {
        return FieldCheck(ok=False, error="Website must be a valid http(s) URL");
    }
    return FieldCheck(value=v);
}

impl clean_text(raw: str, limit: int, label: str) -> FieldCheck {
    v = raw.strip();
    if len(v) > limit {
        return FieldCheck(
            ok=False, error=f"{label} must be {limit} characters or fewer"
        );
    }
    return FieldCheck(value=v);
}

impl decode_avatar(data_url: str) -> AvatarCheck {
    m = re.`match(
        r"^data:image/(jpeg|png|webp);base64,([A-Za-z0-9+/=\s]+)$", data_url.strip()
    );
    if m is None {
        return AvatarCheck(error="Avatar must be a JPEG, PNG or WebP image");
    }
    kind = m.group(1) as str;
    payload = re.sub(r"\s+", "", m.group(2) as str);
    try {
        raw = base64.b64decode(payload, validate=True);
    } except Exception {
        return AvatarCheck(error="Avatar image data is not valid base64");
    }
    if len(raw) > MAX_AVATAR_BYTES {
        return AvatarCheck(error="Avatar must be under 384 KB after resizing");
    }
    looks_right = (
        (kind == "jpeg" and raw[0:3] == b"\xff\xd8\xff")
        or (kind == "png" and raw[0:4] == b"\x89PNG")
        or (kind == "webp" and raw[0:4] == b"RIFF" and raw[8:12] == b"WEBP")
    );
    if not looks_right {
        return AvatarCheck(error="Avatar bytes do not match the declared image type");
    }
    return AvatarCheck(ok=True, mime="image/" + kind, data=payload);
}

impl find_profile_by_username(username: str) -> Profile | None {
    wanted = username.strip().lower();
    if wanted == "" {
        return None;
    }
    for r in allroots() {
        for p in [r-->[?:Profile]] {
            if p.username.lower() == wanted {
                return p;
            }
        }
    }
    return None;
}

impl setup_profile.run with Root entry {
    visit [-->[?:Profile]] else {
        fresh = here ++> Profile(created_at=_now());
        grant(fresh, level=AccessLevel.CONNECT);
        visit fresh;
    }
}

impl setup_profile.apply with Profile entry {
    if self.username {
        here.username = self.username;
    }
    if self.bio {
        here.bio = self.bio;
    }
    report here.to_bundle();
}

impl update_profile.run with Root entry {
    visit [-->[?:Profile]] else {
        report ProfileResult(error="Set up your profile first");
    }
}

impl update_profile.apply with Profile entry {
    checks = [
        clean_text(self.display_name, MAX_DISPLAY_NAME, "Display name"),
        clean_text(self.bio, MAX_BIO, "Bio"),
        clean_text(self.location, MAX_LOCATION, "Location"),
        clean_website(self.website),
        clean_github(self.github)
    ];
    for c in checks {
        if not c.ok {
            report ProfileResult(error=c.error);
            disengage;
        }
    }
    here.display_name = checks[0].value;
    here.bio = checks[1].value;
    here.location = checks[2].value;
    here.website = checks[3].value;
    here.github = checks[4].value;
    report ProfileResult(ok=True, bundle=here.to_bundle());
}

impl get_profile.run with Root entry {
    visit [-->[?:Profile]];
}

impl get_profile.give with Profile entry {
    report here.to_bundle();
}

impl get_user_profile.run with Root entry {
    found = find_profile_by_username(self.username);
    if found is None {
        report ProfileResult(error="No such user");
    } else {
        report ProfileResult(ok=True, bundle=found.to_bundle());
    }
}

impl set_avatar.run with Root entry {
    visit [-->[?:Profile]] else {
        report AvatarResult(error="Set up your profile first");
    }
}

impl set_avatar.apply with Profile entry {
    check = decode_avatar(self.data_url);
    if not check.ok {
        report AvatarResult(error=check.error);
        disengage;
    }
    stamp = now_iso();
    existing = [here->:HasAvatar:->[?:Avatar]];
    if existing {
        existing[0].mime = check.mime;
        existing[0].data = check.data;
        existing[0].updated_at = stamp;
    } else {
        fresh = here +>:HasAvatar():+> Avatar(
            mime=check.mime, data=check.data, updated_at=stamp
        );
        grant(fresh, level=AccessLevel.READ);
    }
    here.avatar_v = stamp;
    report AvatarResult(ok=True, avatar_v=stamp, avatar_url=here.avatar_url());
}

impl clear_avatar.run with Root entry {
    visit [-->[?:Profile]] else {
        report AvatarResult(error="Set up your profile first");
    }
}

impl clear_avatar.apply with Profile entry {
    for av in [here->:HasAvatar:->[?:Avatar]] {
        del av;
    }
    here.avatar_v = "";
    report AvatarResult(ok=True);
}

impl get_avatars.run with Root entry {
    wanted: dict[str, bool] = {};
    for u in self.usernames {
        wanted[u.lower()] = True;
    }
    for r in allroots() {
        for p in [r-->[?:Profile]] {
            if p.username.lower() in wanted and p.avatar_v != "" {
                self.found[p.username] = p.avatar_url();
            }
        }
    }
    report self.found;
}

impl get_all_profiles.run with Root entry {
    for r in allroots() {
        visit [r-->[?:Profile]];
    }
}

impl get_all_profiles.gather with Profile entry {
    self.results.append(here);
}

impl get_all_profiles.deliver with Root exit {
    report self.results;
}

impl get_trending.run with Root entry {
    for r in allroots() {
        visit [r-->[?:Profile]-->[?:Tweet]];
    }
}

impl get_trending.tally with Tweet entry {
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

impl get_trending.deliver with Root exit {
    tags = [TrendingTag(tag=t, count=self.counts[t]) for t in self.counts];
    tags.sort(key=lambda (x: TrendingTag) { x.count; }, reverse=True);
    report tags[:8];
}

impl load_feed.run with Root entry {
    mine = [-->[?:Profile]];
    if mine {
        me = mine[0];
        visit [me-->[?:Tweet]];
        visit [me->:Follow:->[?:Profile]-->[?:Tweet]];
    }
}

impl load_feed.gather with Tweet entry {
    self.feed.append(here);
}

impl load_feed.deliver with Root exit {
    result = self.feed;
    if self.search_query {
        q = self.search_query.lower().strip();
        result = [
            t
            for t in result
            if q in t.content.lower()
        ];
    }
    result.sort(key=lambda (t: Tweet) { t.created_at; }, reverse=True);
    report result;
}

impl get_channels.run with Root entry {
    for r in allroots() {
        visit [r-->[?:Profile]-->[?:Channel]];
    }
}

impl get_channels.gather with Channel entry {
    cid = jid(here);
    if cid not in self.seen {
        self.seen[cid] = True;
        self.results.append(here.to_bundle(False));
    }
}

impl get_channels.deliver with Root exit {
    self.results.sort(
        key=lambda (c: ChannelBundle) { c.channel.created_at; }, reverse=True
    );
    report self.results;
}

impl create_tweet.run with Root entry {
    if not valid_post(self.content) {
        return;
    }
    visit [-->[?:Profile]];
}

impl create_tweet.make with Profile entry {
    denied = posting_limit(jid(root));
    if denied is not None {
        report denied;
        disengage;
    }
    new = here +>:Post():+> Tweet(
        content=self.content, author_username=here.username, created_at=_now()
    );
    grant(new, level=AccessLevel.WRITE);
    report new;
}

impl create_channel.run with Root entry {
    visit [-->[?:Profile]];
}

impl create_channel.make with Profile entry {
    new = here +>:Member():+> Channel(
        name=self.name,
        description=self.description,
        creator_username=here.username,
        created_at=_now()
    );
    grant(new, level=AccessLevel.CONNECT);
    report new.to_bundle(False);
}

impl find_profile.run with Root entry {
    if self.target_id {
        target = jobj(self.target_id);
        if isinstance(target, Profile) {
            visit [target];
        }
    }
}

impl follow_user.act with Profile entry {
    if jid(here) == self.target_id {
        me = [root-->[?:Profile]][0];
        me +>:Follow():+> here;
        report {"success": True};
        disengage;
    }
}

impl unfollow_user.act with Profile entry {
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

impl find_tweet.run with Root entry {
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

impl like_tweet.act with Tweet entry {
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

impl delete_tweet.act with Tweet entry {
    if jid(here) == self.tweet_id and here.author_username == self.actor {
        del here;
        report {"success": True};
        disengage;
    }
}

impl add_comment.act with Tweet entry {
    if not valid_post(self.content) {
        return;
    }
    if jid(here) == self.tweet_id {
        if not [root-->[?:Profile]] {
            disengage;
        }
        denied = posting_limit(jid(root));
        if denied is not None {
            report denied;
            disengage;
        }
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

impl find_channel.run with Root entry {
    if self.channel_id {
        target = jobj(self.channel_id);
        if isinstance(target, Channel) {
            visit [target];
        }
    }
}

impl join_channel.act with Channel entry {
    if jid(here) == self.channel_id {
        me = [root-->[?:Profile]][0];
        if not [edge me->:Member:->here] {
            me +>:Member():+> here;
        }
        report {"success": True};
        disengage;
    }
}

impl leave_channel.act with Channel entry {
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

impl get_channel_detail.act with Channel entry {
    if jid(here) == self.channel_id {
        report here.to_bundle(True);
        disengage;
    }
}

impl create_channel_tweet.act with Channel entry {
    if not valid_post(self.content) {
        return;
    }
    if jid(here) == self.channel_id {
        me = [root-->[?:Profile]][0];
        if [edge me->:Member:->here] {
            denied = posting_limit(jid(root));
            if denied is not None {
                report denied;
                disengage;
            }
            new = here +>:ChannelPost():+> Tweet(
                content=self.content, author_username=me.username, created_at=_now()
            );
            grant(new, level=AccessLevel.WRITE);
            report new;
        }
        disengage;
    }
}
