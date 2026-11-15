import time;

test "only tutorials not yet verified or checked on this jac are swept" {
    items = sweep_items(
        [
            ("current", "a", "published", "0.38.0", ""),
            ("older", "b", "published", "0.37.0", ""),
            ("stale", "c", "stale", "0.37.0", ""),
            ("gone", "d", "removed", "0.37.0", ""),
            ("checked", "e", "stale", "0.37.0", "0.38.0")
        ],
        "0.38.0"
    );
    assert [i.slug for i in items] == ["older", "stale"];
}

test "a tutorial passes only when every block passes" {
    assert sweep_passed([BlockView(ok=True), BlockView(ok=True)]);
    assert not sweep_passed([BlockView(ok=True), BlockView(ok=False)]);
    assert not sweep_passed([]);
}

def _wait_peek(chore: Chore) -> tuple[str, str, any, str] | None;

impl _wait_peek(chore: Chore) -> tuple[str, str, any, str] | None {
    deadline = time.time() + 5;
    seen = chore.peek();
    while seen is None and time.time() < deadline {
        time.sleep(0.01);
        seen = chore.peek();
    }
    return seen;
}

test "a chore keeps its result until it is acknowledged" {
    chore = Chore();

    def work(note: Callable) -> int {
        note("sweep", "halfway");
        return 42;
    }
    assert chore.start("sweep", work);
    assert not chore.start("sweep", work);
    seen = _wait_peek(chore);
    assert seen is not None and seen[1:] == ("sweep", 42, "");
    assert chore.peek() == seen , "an unacknowledged result must survive a retried tick";
    assert not chore.start("pr", lambda (note: Callable) { 1; });
    chore.ack("not-this-run");
    assert chore.peek() == seen;
    chore.ack(seen[0]);
    assert chore.peek() is None and not chore.busy();
    assert chore.start("pr", lambda (note: Callable) { 1 / 0; });
    failed = _wait_peek(chore);
    assert failed is not None
        and failed[1] == "pr"
        and "ZeroDivisionError" in failed[3];
    assert failed[0] != seen[0];
}
