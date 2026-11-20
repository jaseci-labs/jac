test "progress narration caps its log" {
    job = JobProgress();
    job.begin("sync");
    for i in range(20) {
        job.note("step " + str(i));
    }
    assert len(job.log) == 6;
    assert job.log[-1] == "step 19";
    assert job.detail == "step 19";
    assert job.active;
    job.finish();
    assert not job.active;
    assert job.phase == "done";
}

test "progress marks are keyed by label" {
    job = JobProgress();
    job.mark("latest", "wait", "queued");
    job.mark("v0.33", "wait", "queued");
    job.mark("latest", "done", "412 pages");
    assert len(job.steps) == 2;
    assert job.steps[0].state == "done";
    assert job.steps[0].detail == "412 pages";
    assert job.steps[1].state == "wait";
}
