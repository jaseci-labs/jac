impl ClawNode.__jac_access__ -> AccessLevel {
    return AccessLevel.READ;
}

impl ClawEdge.__jac_access__ -> AccessLevel {
    return AccessLevel.READ;
}

impl HasClaw.__jac_access__ -> AccessLevel {
    return AccessLevel.READ;
}

impl find_hub -> ClawHub | None {
    hubs = [root.shared->:HasClaw:->[?:ClawHub]];
    return hubs[0] if hubs else None;
}

impl claw_gaps -> int {
    hub = find_hub();
    return len([hub->:HasGap:->[?:ClawGap]]) if hub is not None else 0;
}

impl claw_hub -> ClawHub {
    found = find_hub();
    if found is not None {
        return found;
    }
    hub = ClawHub(created_at=stamp());
    root.shared +>:HasClaw():+> hub;
    return hub;
}

impl claw_jobs -> list[ClawJob] {
    hub = find_hub();
    if hub is None {
        return [];
    }
    jobs = [hub->:HasJob:->[?:ClawJob]];
    jobs.sort(key=lambda (j: ClawJob) { j.created_at; });
    return jobs;
}

impl claw_tutorials -> list[ClawTutorial] {
    hub = find_hub();
    if hub is None {
        return [];
    }
    found = [hub->:HasTutorial:->[?:ClawTutorial]];
    found.sort(key=lambda (t: ClawTutorial) { t.created_at; }, reverse=True);
    return found;
}

impl tutorial_by_slug(slug: str) -> ClawTutorial | None {
    for t in claw_tutorials() {
        if t.slug == slug {
            return t;
        }
    }
    return None;
}

impl enqueue_asks(asks: list[AskInput]) -> list[str] {
    hub = claw_hub();
    known: dict[str, str] = {};
    for j in [hub->:HasJob:->[?:ClawJob]] {
        known[j.ask_key] = jid(j);
    }
    ids: list[str] = [];
    for ask in asks {
        if ask.ask_key in known {
            ids.append(known[ask.ask_key]);
            continue;
        }
        job = hub +>:HasJob():+> ClawJob(
            ask_key=ask.ask_key,
            tweet_id=ask.tweet_id,
            asker=ask.asker,
            question=ask.question[:2000],
            source=ask.source,
            created_at=stamp()
        );
        known[ask.ask_key] = jid(job);
        ids.append(jid(job));
    }
    return ids;
}

impl next_queued -> ClawJob | None {
    for j in claw_jobs() {
        if j.status == "queued" and not j.removed {
            return j;
        }
    }
    return None;
}

impl take_budget -> bool {
    hub = claw_hub();
    today = stamp()[:10];
    if hub.day != today {
        hub.day = today;
        hub.jobs_today = 0;
    }
    if hub.jobs_today >= DAILY_JOBS {
        return False;
    }
    hub.jobs_today = hub.jobs_today + 1;
    return True;
}

impl stamp_in(seconds: float) -> str {
    return (datetime.now(UTC) + timedelta(seconds=seconds)).replace(
        tzinfo=None
    ).isoformat()
        + "Z";
}

impl claim_job(job: ClawJob) {
    job.status = "working";
    job.started_at = stamp();
    job.lease_owner = WORKER_ID;
    job.lease_until = stamp_in(JOB_LEASE_S);
}

impl renew_job(job_id: str) {
    job = jobj(job_id);
    if isinstance(job, ClawJob)
        and job.status == "working"
        and job.lease_owner == WORKER_ID
        and job.lease_until < stamp_in(JOB_LEASE_S / 2) {
        job.lease_until = stamp_in(JOB_LEASE_S);
    }
}

impl requeue_stale {
    now = stamp();
    legacy_cutoff = stamp_in(-STALE_WORKING_S);
    for j in claw_jobs() {
        if j.status != "working" {
            continue;
        }
        lapsed = j.lease_until < now if j.lease_until else j.started_at < legacy_cutoff;
        if lapsed {
            j.status = "queued";
            j.lease_owner = "";
            j.lease_until = "";
            j.steps = j.steps
                + [
                    StepView(
                        at=stamp(),
                        phase="requeue",
                        text="the worker running it stopped; queued again"
                    )
                ];
        }
    }
}

impl slug_for(title: str) -> str {
    base = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")[:60] or "tutorial";
    taken = {t.slug for t in claw_tutorials()};
    slug = base;
    n = 2;
    while slug in taken {
        slug = base + "-" + str(n);
        n += 1;
    }
    return slug;
}

impl record_outcome(job: ClawJob, outcome: Outcome) {
    hub = claw_hub();
    job.attempts = job.attempts + 1;
    if outcome.status == "failed" and job.attempts < MAX_ATTEMPTS and not job.removed {
        job.status = "queued";
        job.detail = outcome.detail;
        job.steps = job.steps
            + outcome.steps
            + [
                StepView(
                    at=stamp(),
                    phase="retry",
                    text="that attempt failed; queued to try once more"
                )
            ];
        return;
    }
    job.status = outcome.status;
    job.outcome = outcome.outcome;
    job.reply = outcome.reply;
    job.detail = outcome.detail;
    job.links = outcome.links;
    job.consulted = outcome.consulted;
    job.blocks = outcome.blocks;
    job.steps = job.steps + outcome.steps;
    job.finished_at = stamp();
    if job.removed {
        job.reply = "";
        job.outcome = "removed";
        job.detail = "the post was removed";
        return;
    }
    slug = outcome.tutorial_slug;
    draft = outcome.tutorial;
    if draft is not None {
        slug = draft.slug or slug_for(draft.title);
        made = hub +>:HasTutorial():+> ClawTutorial(
            slug=slug,
            title=draft.title,
            summary=draft.summary,
            body=draft.body,
            blocks=draft.blocks,
            verified_version=resolve_cli_version(),
            job_id=jid(job),
            created_at=stamp()
        );
        job.reply = job.reply.replace("{tutorial}", "/jacyac/tutorials/" + slug);
    }
    job.tutorial_slug = slug;
    if slug {
        t = tutorial_by_slug(slug);
        if t is not None {
            t +>:Answered():+> job;
            if job.asker and job.asker not in t.askers {
                t.askers = t.askers + [job.asker];
            }
            t.answered = len(t.askers);
        }
    }
    if outcome.outcome == "gap" {
        hub +>:HasGap():+> ClawGap(
            question=job.question[:400], job_id=jid(job), created_at=stamp()
        );
    }
}

impl job_view(job: ClawJob, live: list[StepView] | None = None) -> JobView {
    return JobView(
        job_id=jid(job),
        asker=job.asker,
        question=job.question,
        source=job.source,
        status=job.status,
        outcome=job.outcome,
        reply=job.reply,
        detail=job.detail,
        tutorial_slug=job.tutorial_slug,
        links=job.links,
        consulted=job.consulted,
        blocks=job.blocks,
        steps=job.steps + (live or []),
        created_at=job.created_at,
        finished_at=job.finished_at
    );
}

impl tutorial_card(t: ClawTutorial) -> TutorialCard {
    return TutorialCard(
        slug=t.slug,
        title=t.title,
        summary=t.summary,
        status=t.status,
        verified_version=t.verified_version,
        answered=t.answered,
        created_at=t.created_at
    );
}

impl replies_for(job_ids: list[str]) -> list[JobReply] {
    wanted = set(job_ids);
    out: list[JobReply] = [];
    for j in claw_jobs() {
        if jid(j) in wanted {
            out.append(
                JobReply(
                    job_id=jid(j),
                    ask_key=j.ask_key,
                    tweet_id=j.tweet_id,
                    status=j.status,
                    reply=j.reply
                )
            );
        }
    }
    return out;
}

impl sweep_inputs -> list[tuple[str, str, str, str, str]] {
    return [
        (t.slug, t.body, t.status, t.verified_version, t.checked_version)
        for t in claw_tutorials()
    ];
}

impl apply_sweep(
    results: dict[str, list[BlockView]],
    version: str,
    error: str,
    complete: bool = False
) {
    hub = claw_hub();
    for t in claw_tutorials() {
        blocks = results.get(t.slug);
        if blocks is None {
            continue;
        }
        t.checked_version = version;
        t.blocks = blocks;
        if sweep_passed(blocks) {
            t.status = "published";
            t.verified_version = version;
        } else {
            t.status = "stale";
        }
    }
    current = [
        t
        for t in claw_tutorials()
        if t.status != "removed"
    ];
    hub.last_sweep_at = stamp();
    if complete and not error {
        hub.swept_version = version;
    }
    hub.sweep_passed = len(
        [
            t
            for t in current
            if t.status == "published" and t.verified_version == version
        ]
    );
    hub.sweep_stale = len(
        [
            t
            for t in current
            if t.status == "stale"
        ]
    );
}

impl promote_candidates -> list[PromoteCandidate] {
    return [
        PromoteCandidate(
            slug=t.slug,
            title=t.title,
            summary=t.summary,
            body=t.body,
            askers=t.answered,
            created_at=t.created_at,
            verified_version=t.verified_version,
            status=t.status,
            pr_state=t.pr_state
        ) for t in claw_tutorials()
    ];
}

impl apply_pr(slug: str, result: PrResult) {
    hub = claw_hub();
    hub.pr_state = result.state;
    hub.pr_url = result.url;
    hub.pr_note = result.note;
    hub.pr_checked_at = stamp();
    if result.state != "open" {
        return;
    }
    hub.pr_number = result.number;
    hub.pr_slug = slug;
    t = tutorial_by_slug(slug);
    if t is not None {
        t.pr_state = "open";
        t.pr_url = result.url;
    }
}

impl pr_checked_recently(hub: ClawHub) -> bool {
    cutoff = (datetime.now(UTC) - timedelta(seconds=PR_POLL_S)).replace(
        tzinfo=None
    ).isoformat()
        + "Z";
    return hub.pr_checked_at > cutoff;
}

impl pr_due -> bool {
    hub = find_hub();
    if hub is None or hub.pr_state != "open" or not hub.pr_number {
        return False;
    }
    return not pr_checked_recently(hub);
}

impl pr_cooling -> bool {
    hub = find_hub();
    if hub is None {
        return False;
    }
    if hub.pr_state == "open" {
        return True;
    }
    return hub.pr_state == "failed" and pr_checked_recently(hub);
}

impl apply_pr_state(state: str) {
    hub = claw_hub();
    hub.pr_checked_at = stamp();
    if not state or state == "open" {
        return;
    }
    hub.pr_state = state;
    hub.pr_note = "the docs PR was " + state;
    t = tutorial_by_slug(hub.pr_slug);
    if t is not None {
        t.pr_state = state;
    }
    hub.pr_number = 0;
}

impl forget_jobs(job_ids: list[str]) -> int {
    hub = find_hub();
    if hub is None {
        return 0;
    }
    wanted = set(job_ids);
    count = 0;
    for j in [hub->:HasJob:->[?:ClawJob]] {
        if jid(j) not in wanted or j.removed {
            continue;
        }
        j.removed = True;
        j.question = "";
        if j.status == "queued" {
            j.status = "done";
            j.outcome = "removed";
            j.finished_at = stamp();
        }
        count += 1;
    }
    for gap in [hub->:HasGap:->[?:ClawGap]] {
        if gap.job_id in wanted {
            del gap;
        }
    }
    return count;
}

impl prune_jobs(keep: int) -> int {
    hub = find_hub();
    if hub is None {
        return 0;
    }
    finished = [
        j
        for j in [hub->:HasJob:->[?:ClawJob]]
        if j.status not in ("queued", "working")
    ];
    if len(finished) <= keep {
        return 0;
    }
    finished.sort(key=lambda (j: ClawJob) { j.finished_at or j.created_at; });
    written = {t.job_id for t in claw_tutorials()};
    count = 0;
    for j in finished[:len(finished) - keep] {
        if jid(j) in written {
            continue;
        }
        del j;
        count += 1;
    }
    return count;
}

impl claim_chore -> bool {
    hub = claw_hub();
    if hub.chore_owner and hub.chore_owner != WORKER_ID and hub.chore_until > stamp() {
        return False;
    }
    hub.chore_owner = WORKER_ID;
    hub.chore_until = stamp_in(CHORE_LEASE_S);
    return True;
}

impl renew_chore {
    hub = find_hub();
    if hub is not None
        and hub.chore_owner == WORKER_ID
        and hub.chore_until < stamp_in(CHORE_LEASE_S / 2) {
        hub.chore_until = stamp_in(CHORE_LEASE_S);
    }
}

impl release_chore {
    hub = find_hub();
    if hub is not None and hub.chore_owner == WORKER_ID {
        hub.chore_owner = "";
        hub.chore_until = "";
    }
}
