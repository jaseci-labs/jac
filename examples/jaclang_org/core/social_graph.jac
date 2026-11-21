import re;
import base64;
import datetime;
import os;
import from stdjac { AccessLevel, allroots, grant, jobj, remove }

def _now -> str;

def avatar_url_of(self_: Profile) -> str;

def profile_bundle(self_: Profile) -> ProfileBundle;

def channel_bundle(self_: Channel, with_posts: bool) -> ChannelBundle;

glob MAX_DISPLAY_NAME: int = 50,
     MAX_BIO: int = 280,
     MAX_LOCATION: int = 60,
     MAX_WEBSITE: int = 200,
     MAX_AVATAR_BYTES: int = 393216;

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

comptime DESK_TICK_S: float = 15.0;

glob NINJACLAW: str = "ninjaclaw",
     HELP_CHANNEL: str = "help",
     ASKS_PER_HOUR: int = int(os.environ.get("NINJACLAW_ASKS_PER_HOUR", "3") or 3),
     SCAN_GRACE_S: float = 600.0,
     ASKED_LIMIT: int = 2000,
     MENTION_RE: str = r"(?<![\w@])@ninjaclaw\b";

def mentions_ninjaclaw(text: str) -> bool;

def strip_mention(text: str) -> str;

"""Every root a profile hangs off: each caller's own, and the shared one,
which holds ninjaclaw's: it is no caller's, and its desk runs for none."""
def everyones_roots -> list[Root];

"""ninjaclaw's profile, made the first time: under the shared root."""
def ninjaclaw_profile -> Profile;

def help_channel(claw: Profile) -> Channel;

def live_tweets -> dict[str, Tweet];

def scan_floor(desk: NinjaclawDesk) -> str;

def desk_asks(desk: NinjaclawDesk, help: Channel, tweets: dict[str, Tweet]) -> list[AskInput];

def throttled(desk: NinjaclawDesk, asker: str) -> bool;

def post_reply(tweet_id: str, reply: str) -> bool;

@schedule(interval=DESK_TICK_S)
async def ninjaclaw_desk_tick;

def clean_github(raw: str) -> FieldCheck;

def clean_website(raw: str) -> FieldCheck;

def clean_text(raw: str, limit: int, label: str) -> FieldCheck;

def decode_avatar(data_url: str) -> AvatarCheck;

def find_profile_by_username(username: str) -> Profile | None;

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
        reports: list[Posted] = [];

    can run with Root entry;
    can make with Profile entry;
}

walker:protect create_channel {
    has name: str,
        description: str = "",
        reports: list[ChannelBundle] = [];

    can run with Root entry;
    can make with Profile entry;
}

walker:protect find_profile {
    has target_id: str = "";

    can run with Root entry;
}

walker:protect follow_user(find_profile) {
    has reports: list[dict[str, bool]] = [];

    can act with Profile entry;
}

walker:protect unfollow_user(find_profile) {
    has reports: list[dict[str, bool]] = [];

    can act with Profile entry;
}

walker:protect find_tweet {
    has tweet_id: str = "",
        actor: str = "";

    can run with Root entry;
}

walker:protect like_tweet(find_tweet) {
    has reports: list[Liked] = [];

    can act with Tweet entry;
}

walker:protect delete_tweet(find_tweet) {
    has reports: list[dict[str, bool]] = [];

    can act with Tweet entry;
}

walker:protect add_comment(find_tweet) {
    has content: str = "",
        reports: list[Commented] = [];

    can act with Tweet entry;
}

walker:protect find_channel {
    has channel_id: str = "";

    can run with Root entry;
}

walker:protect join_channel(find_channel) {
    has reports: list[dict[str, bool]] = [];

    can act with Channel entry;
}

walker:protect leave_channel(find_channel) {
    has reports: list[dict[str, bool]] = [];

    can act with Channel entry;
}

walker:protect get_channel_detail(find_channel) {
    has reports: list[ChannelBundle] = [];

    can act with Channel entry;
}

walker:protect create_channel_tweet(find_channel) {
    has content: str = "",
        reports: list[Posted] = [];

    can act with Channel entry;
}
