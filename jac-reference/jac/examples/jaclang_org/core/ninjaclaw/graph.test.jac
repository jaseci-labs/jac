def _job(job_id: str) -> ClawJob;

impl _job(job_id: str) -> ClawJob {
    found = jobj(job_id);
    assert isinstance(found, ClawJob);
    return found;
}

test "a removed post's job is hidden, never worked, and its gap is dropped" {
    ids = enqueue_asks(
        [
            AskInput(
                ask_key="k1", tweet_id="t1", asker="ann", question="how do walkers work"
            ),
            AskInput(
                ask_key="k2", tweet_id="t2", asker="bob", question="what is a node"
            )
        ]
    );
    hub = claw_hub();
    hub +>:HasGap():+> ClawGap(question="how do walkers work", job_id=ids[0]);
    assert forget_jobs([ids[0]]) == 1;
    assert forget_jobs([ids[0]]) == 0;
    gone = _job(ids[0]);
    assert gone.removed and gone.question == "" and gone.outcome == "removed";
    assert [hub->:HasGap:->[?:ClawGap]] == [];
    nxt = next_queued();
    assert nxt is not None and jid(nxt) == ids[1];
    record_outcome(gone, Outcome(status="failed", outcome="failed"));
    assert gone.status == "failed";
}

test "pruning keeps the newest finished jobs and any job that wrote a tutorial" {
    ids = enqueue_asks(
        [
            AskInput(ask_key="p" + str(n), asker="ann", question="question " + str(n))
            for n in range(4)
        ]
    );
    for (n, job_id) in enumerate(ids) {
        job = _job(job_id);
        job.status = "done";
        job.finished_at = "2026-01-0" + str(n + 1) + "T00:00:00Z";
    }
    claw_hub() +>:HasTutorial():+> ClawTutorial(slug="kept", job_id=ids[0]);
    before = len(claw_jobs());
    pruned = prune_jobs(
        len(
            [
                j
                for j in claw_jobs()
                if j.status not in ("queued", "working")
            ]
        )
            - 2
    );
    assert pruned == 1;
    assert len(claw_jobs()) == before - 1;
    assert jobj(ids[0]) is not None;
    assert ids[1] not in [jid(j) for j in claw_jobs()];
}

test "a removed job's finished attempt publishes nothing and records no gap" {
    ids = enqueue_asks(
        [
            AskInput(
                ask_key="rm-gap",
                tweet_id="t-rm",
                asker="cy",
                question="how do edges work"
            )
        ]
    );
    job = _job(ids[0]);
    job.status = "working";
    forget_jobs([ids[0]]);
    hub = claw_hub();
    gaps_before = len([hub->:HasGap:->[?:ClawGap]]);
    record_outcome(
        job,
        Outcome(
            status="done", outcome="gap", reply="no answer yet: /jacyac/ninjaclaw/x"
        )
    );
    assert job.outcome == "removed" and job.reply == "";
    assert len([hub->:HasGap:->[?:ClawGap]]) == gaps_before;
}

test "a job leased by another worker is left alone until its lease lapses" {
    ids = enqueue_asks(
        [
            AskInput(
                ask_key="lease-1",
                tweet_id="t-l1",
                asker="dee",
                question="what is a walker"
            )
        ]
    );
    job = _job(ids[0]);
    job.status = "working";
    job.started_at = stamp_in(-5000.0);
    job.lease_owner = "other-host:1:abcd";
    job.lease_until = stamp_in(60.0);
    requeue_stale();
    assert job.status == "working" , "a live lease must not be requeued, however old the job";
    job.lease_until = stamp_in(-1.0);
    requeue_stale();
    assert job.status == "queued" and job.lease_owner == "";
    claim_job(job);
    assert job.status == "working" and job.lease_owner == WORKER_ID;
}

test "a chore claim excludes other workers until it expires or is released" {
    hub = claw_hub();
    hub.chore_owner = "other-host:2:ef01";
    hub.chore_until = stamp_in(60.0);
    assert not claim_chore();
    hub.chore_until = stamp_in(-1.0);
    assert claim_chore() and hub.chore_owner == WORKER_ID;
    release_chore();
    assert hub.chore_owner == "";
}

test "a partial sweep marks what it checked and completes only after the last batch" {
    hub = claw_hub();
    hub +>:HasTutorial():+> ClawTutorial(
        slug="sweep-a", status="published", verified_version="0.1.0"
    );
    hub +>:HasTutorial():+> ClawTutorial(
        slug="sweep-b", status="published", verified_version="0.1.0"
    );
    apply_sweep({"sweep-a": [BlockView(index=0, ok=True)]}, "0.2.0", "");
    assert hub.swept_version != "0.2.0" , "a batch is not the whole sweep";
    a = tutorial_by_slug("sweep-a");
    b = tutorial_by_slug("sweep-b");
    assert a is not None and b is not None;
    assert a.checked_version == "0.2.0";
    assert b.checked_version == "";
    apply_sweep({}, "0.2.0", "", True);
    assert hub.swept_version == "0.2.0";
}
