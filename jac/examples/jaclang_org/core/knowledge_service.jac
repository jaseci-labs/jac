import logging;
import os;
import from datetime { datetime, UTC }
import from jaclang.cli.manifest_route { resolve_cli_version }

obj ReleaseDocsInfo {
    has label: str = "",
        tag: str = "",
        version: str = "",
        fingerprint: str = "";
}

obj ReleaseLines {
    has ready: bool = False,
        serving_label: str = "",
        lines: list[ReleaseDocsInfo] = [];
}

glob REPO_TICK_S: float = 60.0,
     WORK_TICK_S: float = 5.0,
     UPKEEP_TICK_S: float = 60.0,
     SWEEP_BATCH: int = 5,
     QUEUE_LIMIT: int = 20,
     _BUNDLES: dict[str, DocBundle] = {},
     _CATALOG: dict[str, list[IndexDoc]] = {},
     log: logging.Logger = logging.getLogger("knowledge");

def release_bundle(line: ReleaseLine) -> DocBundle;

@schedule(trigger=ScheduleTrigger.STATIC, interval=REPO_TICK_S)
def:priv knowledge_repo_tick;

def:pub knowledge_status -> RepoStatus;

def:pub release_doc_lines -> ReleaseLines;

def:pub release_docs(tag: str) -> DocBundle | None;

def ninjaclaw_enabled -> tuple[bool, str];

def docs_catalog -> list[IndexDoc];

def tutorial_catalog -> list[IndexDoc];

def public_view(job: ClawJob, live: list[StepView] | None = None) -> JobView;

@schedule(trigger=ScheduleTrigger.STATIC, interval=WORK_TICK_S)
def:priv ninjaclaw_work_tick;

@schedule(trigger=ScheduleTrigger.STATIC, interval=UPKEEP_TICK_S)
def:priv ninjaclaw_upkeep_tick;

def finish_chore;

def start_sweep(version: str) -> bool;

def start_promotion;

def:pub ninjaclaw_submit(secret: str, asks: list[AskInput]) -> list[str];

def:pub ninjaclaw_results(secret: str, job_ids: list[str]) -> list[JobReply];

def:pub ninjaclaw_forget(secret: str, job_ids: list[str]) -> int;

def:pub ninjaclaw_retained(secret: str, job_ids: list[str]) -> list[str];

def:pub ninjaclaw_activity -> Activity;

def:pub ninjaclaw_job(job_id: str) -> JobView | None;

def:pub ninjaclaw_tutorials -> list[TutorialCard];

def:pub ninjaclaw_tutorial(slug: str) -> TutorialView | None;

impl release_bundle(line: ReleaseLine) -> DocBundle {
    cached = _BUNDLES.get(line.tag);
    if cached is None {
        cached = bundle_from(export_docs(line), line.version);
        _BUNDLES[line.tag] = cached;
    }
    return cached;
}

impl knowledge_repo_tick {
    status = ensure_repo(resolve_cli_version());
    if status.phase != "ready" {
        log.info("knowledge: repo " + status.phase + " " + status.detail);
    }
}

impl knowledge_status -> RepoStatus {
    return read_status();
}

impl release_doc_lines -> ReleaseLines {
    status = read_status();
    answer = ReleaseLines(
        ready=status.phase == "ready",
        serving_label=label_of(status.serving_version or resolve_cli_version())
    );
    if not answer.ready {
        return answer;
    }
    for line in status.lines {
        bundle = release_bundle(line);
        answer.lines.append(
            ReleaseDocsInfo(
                label=line.label,
                tag=line.tag,
                version=line.version,
                fingerprint=bundle.fingerprint
            )
        );
    }
    return answer;
}

impl release_docs(tag: str) -> DocBundle | None {
    for line in read_status().lines {
        if line.tag == tag {
            return release_bundle(line);
        }
    }
    return None;
}

impl ninjaclaw_enabled -> tuple[bool, str] {
    if os.environ.get("NINJACLAW_ENABLED", "1").strip().lower()
        in ("0", "false", "no", "off") {
        return (False, "turned off on this server (NINJACLAW_ENABLED=0)");
    }
    if not os.environ.get("ANTHROPIC_API_KEY", "").strip() {
        return (False, "no model key on this server (ANTHROPIC_API_KEY is unset)");
    }
    status = read_status();
    if status.phase != "ready" {
        return (
            False,
            "warming up: the jac repo is " + (status.phase or "not cloned yet")
        );
    }
    return (True, "");
}

impl docs_catalog -> list[IndexDoc] {
    status = read_status();
    root_dir = checkout_root();
    if root_dir is None {
        return [];
    }
    cached = _CATALOG.get(status.checked_out);
    if cached is None {
        cached = docs_from_tree(root_dir / DOCS_PATH);
        _CATALOG.clear();
        _CATALOG[status.checked_out] = cached;
    }
    return cached;
}

impl tutorial_catalog -> list[IndexDoc] {
    return [
        index_doc(
            "tutorial",
            t.slug,
            t.title,
            "/jacyac/tutorials/" + t.slug,
            t.summary + "\n\n" + t.body
        )
        for t in claw_tutorials()
        if t.status == "published"
    ];
}

impl public_view(job: ClawJob, live: list[StepView] | None = None) -> JobView {
    view = job_view(job, live);
    if job.removed {
        view.question = "";
        view.detail = "the post was removed";
    } elif job.outcome == "ignored" {
        view.question = "";
        view.detail = "ignored: not a Jac question";
    }
    return view;
}

impl ninjaclaw_work_tick {
    applied: list[str] = [];
    for res in RUNNER.pending() {
        job = jobj(res.job_id);
        if not isinstance(job, ClawJob) or job.applied_run == res.run_id {
            applied.append(res.run_id);
            continue;
        }
        record_outcome(job, res.outcome);
        job.applied_run = res.run_id;
    }
    RUNNER.ack(applied);
    (spec, _steps) = RUNNER.live();
    if spec is not None {
        renew_job(spec.job_id);
    }
    requeue_stale();
    (ok, _why) = ninjaclaw_enabled();
    if not ok or RUNNER.busy() {
        return;
    }
    job = next_queued();
    if job is None {
        return;
    }
    if not take_budget() {
        record_outcome(
            job,
            Outcome(
                outcome="throttled",
                reply="I've reached today's answer budget; ask me again tomorrow."
            )
        );
        return;
    }
    claim_job(job);
    RUNNER.start(
        JobSpec(
            job_id=jid(job),
            question=job.question,
            asker=job.asker,
            source=job.source,
            repo_root=str(checkout_root() or ""),
            version=resolve_cli_version()
        ),
        tutorial_catalog() + docs_catalog(),
        run_pipeline
    );
}

impl ninjaclaw_upkeep_tick {
    finish_chore();
    if CHORE.busy() {
        renew_chore();
    }
    pruned = prune_jobs(JOB_RETENTION);
    if pruned {
        log.info("ninjaclaw: pruned " + str(pruned) + " old job(s)");
    }
    (ok, _why) = ninjaclaw_enabled();
    if not ok or CHORE.busy() or RUNNER.busy() {
        return;
    }
    version = resolve_cli_version();
    hub = find_hub();
    if hub is not None and hub.swept_version != version and start_sweep(version) {
        return;
    }
    start_promotion();
}

impl finish_chore {
    finished = CHORE.peek();
    if finished is None {
        return;
    }
    (run_id, kind, result, error) = finished;
    if claw_hub().applied_chore == run_id {
        CHORE.ack(run_id);
        return;
    }
    if kind == "sweep" {
        (version, results) = result if result is not None else ("", {});
        if error {
            log.warning("ninjaclaw: re-verification failed: " + error);
        }
        apply_sweep(results, version, error);
    } elif kind == "pr" {
        (slug, pr) = result if result is not None else ("", PrResult());
        if error {
            pr = PrResult(state="failed", note=error);
            log.warning("ninjaclaw: docs PR failed: " + error);
        }
        apply_pr(slug, pr);
    } elif kind == "pr-poll" {
        if error {
            log.warning("ninjaclaw: docs PR check failed: " + error);
        }
        apply_pr_state(result or "");
    }
    claw_hub().applied_chore = run_id;
    release_chore();
}

impl start_sweep(version: str) -> bool {
    items = sweep_items(sweep_inputs(), version);
    if not items {
        apply_sweep({}, version, "", True);
        return False;
    }
    left = len(items);
    items = items[:SWEEP_BATCH];
    if not claim_chore() {
        return True;
    }
    log.info(
        "ninjaclaw: re-verifying "
            + str(len(items))
            + " of "
            + str(left)
            + " tutorial(s) on jac "
            + version
    );

    def work(note: Callable) -> tuple[str, dict[str, list[BlockView]]] {
        return (version, sweep(items, note));
    }
    return CHORE.start("sweep", work);
}

impl start_promotion {
    config = promote_config();
    if not promote_ready(config) {
        return;
    }
    if pr_due() {
        hub = claw_hub();
        number = hub.pr_number;

        def poll(note: Callable) -> str {
            return pr_state(number, config, github);
        }
        if claim_chore() {
            CHORE.start("pr-poll", poll);
        }
        return;
    }
    if pr_cooling() {
        return;
    }
    pick = eligible(
        promote_candidates(), resolve_cli_version(), config, datetime.now(UTC)
    );
    if pick is None or not claim_chore() {
        return;
    }
    if config.dry_run {
        apply_pr(pick.slug, open_docs_pr(pick, config, github));
        release_chore();
        return;
    }
    log.info("ninjaclaw: opening a docs PR for " + pick.slug);

    def promote(note: Callable) -> tuple[str, PrResult] {
        return (pick.slug, open_docs_pr(pick, config, github));
    }
    CHORE.start("pr", promote);
}

impl ninjaclaw_submit(secret: str, asks: list[AskInput]) -> list[str] {
    if not secret_ok(secret) {
        return [];
    }
    return enqueue_asks(asks);
}

impl ninjaclaw_forget(secret: str, job_ids: list[str]) -> int {
    if not secret_ok(secret) {
        return 0;
    }
    return forget_jobs(job_ids);
}

impl ninjaclaw_retained(secret: str, job_ids: list[str]) -> list[str] {
    if not secret_ok(secret) {
        return list(job_ids);
    }
    wanted = set(job_ids);
    return [
        jid(j)
        for j in claw_jobs()
        if jid(j) in wanted
    ];
}

impl ninjaclaw_results(secret: str, job_ids: list[str]) -> list[JobReply] {
    if not secret_ok(secret) {
        return [];
    }
    return replies_for(job_ids);
}

impl ninjaclaw_activity -> Activity {
    (ok, why) = ninjaclaw_enabled();
    status = read_status();
    hub = find_hub() or ClawHub();
    (spec, live) = RUNNER.live();
    jobs = claw_jobs();
    current: JobView | None = None;
    queue: list[JobView] = [];
    recent: list[JobView] = [];
    for j in jobs {
        if j.status == "working" {
            current = public_view(
                j, live if spec is not None and spec.job_id == jid(j) else []
            );
        } elif j.status == "queued" {
            if len(queue) < QUEUE_LIMIT {
                queue.append(public_view(j));
            }
        }
    }
    finished = [
        j
        for j in jobs
        if j.status not in ("queued", "working")
    ];
    finished.sort(key=lambda (j: ClawJob) { j.finished_at; }, reverse=True);
    for j in finished[:RECENT_LIMIT] {
        recent.append(public_view(j));
    }
    state = "off" if not ok else ("working" if current is not None else "idle");
    if not ok and status.phase != "ready" and "warming" in why {
        state = "warming";
    }
    return Activity(
        enabled=ok,
        state=state,
        detail=why,
        repo_phase=status.phase,
        serving_version=status.serving_version or resolve_cli_version(),
        current=current,
        queue=queue,
        recent=recent,
        upkeep=UpkeepView(
            last_sweep_at=hub.last_sweep_at,
            swept_version=hub.swept_version,
            passed=hub.sweep_passed,
            stale=hub.sweep_stale,
            pr_state=hub.pr_state,
            pr_url=hub.pr_url,
            pr_note=hub.pr_note,
            running=CHORE.status()[1] if CHORE.status()[0] == "sweep" else ""
        ),
        tutorials=len(
            [
                t
                for t in claw_tutorials()
                if t.status == "published"
            ]
        ),
        gaps=claw_gaps()
    );
}

impl ninjaclaw_job(job_id: str) -> JobView | None {
    job = jobj(job_id);
    if not isinstance(job, ClawJob) {
        return None;
    }
    (spec, live) = RUNNER.live();
    return public_view(job, live if spec is not None and spec.job_id == job_id else []);
}

impl ninjaclaw_tutorials -> list[TutorialCard] {
    return [
        tutorial_card(t)
        for t in claw_tutorials()
        if t.status != "removed"
    ];
}

impl ninjaclaw_tutorial(slug: str) -> TutorialView | None {
    t = tutorial_by_slug(slug);
    if t is None or t.status == "removed" {
        return None;
    }
    return TutorialView(
        card=tutorial_card(t),
        body=t.body,
        blocks=t.blocks,
        job_id=t.job_id,
        pr_url=t.pr_url
    );
}
