"""Tests for the StateBackend in-process default: the non-trivial behavior only
(TTL expiry, exclusive locking, atomic increment)."""

import time;
import from jac_scale.state.state_backend { InProcessStateBackend }


test "a value past its ttl is dropped on read, one without a ttl persists" {
    backend = InProcessStateBackend();
    backend.set("durable", "v");
    backend.set("ephemeral", "v", ttl_seconds=0);
    time.sleep(0.02);
    assert backend.get("durable") == "v";
    assert backend.get("ephemeral") is None;
}


test "acquire_lock is exclusive until released" {
    backend = InProcessStateBackend();
    assert backend.acquire_lock("job", 60);
    assert not backend.acquire_lock("job", 60);
    backend.release_lock("job");
    assert backend.acquire_lock("job", 60);
}


test "increment accumulates atomically and returns the new total" {
    backend = InProcessStateBackend();
    assert backend.increment("counter", 1.0) == 1.0;
    assert backend.increment("counter", 2.5) == 3.5;
}
