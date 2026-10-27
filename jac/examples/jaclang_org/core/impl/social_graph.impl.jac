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
