impl mentions_ninjaclaw(text: str) -> bool {
    return re.search(MENTION_RE, text, re.IGNORECASE) is not None;
}

impl strip_mention(text: str) -> str {
    return re.sub(
        r"\s+", " ", re.sub(MENTION_RE, "", text, flags=re.IGNORECASE)
    ).strip();
}

impl ninjaclaw_profile -> Profile {
    found = [root-->[?:Profile, username==NINJACLAW]];
    if found {
        return found[0];
    }
    claw = root ++> Profile(
        username=NINJACLAW,
        display_name="ninjaclaw",
        bio="I answer Jac questions on JacYac. Mention @ninjaclaw or post in #help. Everything I do is public at /jacyac/ninjaclaw.",
        created_at=_now()
    );
    grant(claw, level=AccessLevel.CONNECT);
    return claw;
}

impl help_channel(claw: Profile) -> Channel {
    found = [claw->:Member:->[?:Channel, name==HELP_CHANNEL]];
    if found {
        return found[0];
    }
    made = claw +>:Member():+> Channel(
        name=HELP_CHANNEL,
        description="Ask anything about Jac. ninjaclaw answers every post here.",
        creator_username=NINJACLAW,
        created_at=_now()
    );
    grant(made, level=AccessLevel.CONNECT);
    return made;
}

impl throttled(desk: NinjaclawDesk, asker: str) -> bool {
    cutoff = (
        datetime.datetime.now(datetime.UTC) - datetime.timedelta(hours=1)
    ).replace(
        tzinfo=None
    ).isoformat()
        + "Z";
    kept = [
        t
        for t in desk.recent_asks.get(asker, [])
        if t >= cutoff
    ];
    if len(kept) >= ASKS_PER_HOUR {
        desk.recent_asks = {** desk.recent_asks, asker: kept};
        return True;
    }
    desk.recent_asks = {** desk.recent_asks, asker: kept + [_now()]};
    return False;
}

impl live_tweets -> dict[str, Tweet] {
    tweets: dict[str, Tweet] = {};
    for r in allroots() {
        for t in [r-->[?:Profile]-->[?:Tweet]] {
            tweets[jid(t)] = t;
        }
        for c in [r-->[?:Profile]->:Member:->[?:Channel]] {
            for t in [c-->[?:Tweet]] {
                tweets[jid(t)] = t;
            }
        }
    }
    return tweets;
}

impl desk_asks(
    desk: NinjaclawDesk, help: Channel, tweets: dict[str, Tweet]
) -> list[AskInput] {
    floor = scan_floor(desk);
    seen = dict(desk.recent_keys);
    newest = desk.seen_until;
    asks: list[AskInput] = [];

    def consider(
        key: str, tweet: Tweet, author: str, text: str, created: str, source: str
    ) {
        if key in seen or created < floor or author == NINJACLAW {
            return;
        }
        seen[key] = created;
        if created > newest {
            newest = created;
        }
        question = strip_mention(text);
        if not question or throttled(desk, author) {
            return;
        }
        asks.append(
            AskInput(
                ask_key=key,
                tweet_id=jid(tweet),
                asker=author,
                question=question,
                source=source,
                asked_at=created
            )
        );
    }

    help_posts = {jid(t) for t in [help-->[?:Tweet]]};
    for (tid, t) in tweets.items() {
        in_help = tid in help_posts;
        if in_help or mentions_ninjaclaw(t.content) {
            consider(
                tid,
                t,
                t.author_username,
                t.content,
                t.created_at,
                "help" if in_help else "mention"
            );
        }
        for (n, c) in enumerate(t.comments) {
            body = str(c.get("content", ""));
            if mentions_ninjaclaw(body) {
                consider(
                    tid + "#c" + str(n),
                    t,
                    str(c.get("username", "")),
                    body,
                    str(c.get("created_at", "")),
                    "mention"
                );
            }
        }
    }
    desk.seen_until = newest;
    keep_from = scan_floor(desk);
    desk.recent_keys = {
        k: c
        for (k, c) in seen.items()
        if c >= keep_from
    };
    return asks;
}

impl scan_floor(desk: NinjaclawDesk) -> str {
    if not desk.seen_until {
        return desk.started_at;
    }
    grace = (
        datetime.datetime.fromisoformat(desk.seen_until.rstrip("Z"))
        - datetime.timedelta(seconds=SCAN_GRACE_S)
    ).isoformat()
        + "Z";
    return max(desk.started_at, grace);
}

impl post_reply(tweet_id: str, reply: str) -> bool {
    target = jobj(tweet_id);
    if not isinstance(target, Tweet) or not valid_post(reply) {
        return False;
    }
    target.comments = target.comments
        + [{"username": NINJACLAW, "content": reply, "created_at": _now()}];
    return True;
}

impl ninjaclaw_desk.run with Root entry {
    desks = [-->[?:NinjaclawDesk]];
    desk = desks[0] if desks else (here ++> NinjaclawDesk(started_at=_now()));
    claw = ninjaclaw_profile();
    help = help_channel(claw);
    secret = service_secret();
    tweets = live_tweets();
    asks = desk_asks(desk, help, tweets);
    if asks {
        ids = await ninjaclaw_submit(secret=secret, asks=asks);
        pending = dict(desk.pending);
        asked = dict(desk.asked);
        for (n, job_id) in enumerate(ids) {
            if n < len(asks) {
                pending[job_id] = asks[n].tweet_id;
                asked[job_id] = asks[n].tweet_id;
            }
        }
        desk.pending = pending;
        desk.asked = asked;
    }
    if len(desk.asked) > ASKED_LIMIT {
        kept = set(await ninjaclaw_retained(secret=secret, job_ids=list(desk.asked)));
        desk.asked = {
            k: v
            for (k, v) in desk.asked.items()
            if k in kept
        };
    }
    gone = [
        job_id
        for (job_id, tweet_id) in desk.asked.items()
        if tweet_id not in tweets
    ];
    if gone {
        await ninjaclaw_forget(secret=secret, job_ids=gone);
        desk.asked = {
            k: v
            for (k, v) in desk.asked.items()
            if k not in gone
        };
        desk.pending = {
            k: v
            for (k, v) in desk.pending.items()
            if k not in gone
        };
    }
    if not desk.pending {
        return;
    }
    replies = await ninjaclaw_results(secret=secret, job_ids=list(desk.pending.keys()));
    pending = dict(desk.pending);
    for r in replies {
        if r.status in ("queued", "working") {
            continue;
        }
        if r.reply {
            post_reply(r.tweet_id, r.reply);
        }
        pending.pop(r.job_id, None);
    }
    desk.pending = pending;
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
