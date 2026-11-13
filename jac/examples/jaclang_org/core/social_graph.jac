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
