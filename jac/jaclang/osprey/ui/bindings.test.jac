test "subscribe and unsubscribe round trip" {
    registry = BindingRegistry();
    assert subscribe(registry, "session.events", "target-1", "TranscriptChanged");
    assert binding_count(registry) == 1;
    assert not is_empty(registry);
    assert unsubscribe(registry, "session.events", "target-1", "TranscriptChanged");
    assert is_empty(registry);
    assert binding_count(registry) == 0;
}


test "deliver routes to correct targets" {
    registry = BindingRegistry();
    subscribe(registry, "session.events", "transcript-id", "TranscriptChanged");
    subscribe(registry, "session.events", "other-id", "TranscriptChanged");
    subscribe(registry, "session.phase", "status-id", "PhaseChanged");

    results: list[DeliveryResult] = deliver(
        registry, "session.events", "TranscriptChanged"
    );
    assert len(results) == 2;
    assert results[0].target_id == "other-id";
    assert results[0].event_type == "TranscriptChanged";
    assert results[0].delivered;
    assert results[1].target_id == "transcript-id";
    assert len(deliver(registry, "session.phase", "PhaseChanged")) == 1;
    assert len(deliver(registry, "session.events", "PhaseChanged")) == 0;
}


test "duplicate subscribe is rejected" {
    registry = BindingRegistry();
    assert subscribe(registry, "session.events", "target-1", "TranscriptChanged");
    assert not subscribe(registry, "session.events", "target-1", "TranscriptChanged");
    assert binding_count(registry) == 1;
}


test "unsubscribe_target clears all bindings for one target" {
    registry = BindingRegistry();
    subscribe(registry, "session.events", "shared", "TranscriptChanged");
    subscribe(registry, "session.phase", "shared", "PhaseChanged");
    subscribe(registry, "session.events", "other", "TranscriptChanged");

    removed = unsubscribe_target(registry, "shared");
    assert removed == 2;
    assert binding_count(registry) == 1;

    assert len(bindings_for_target(registry, "shared")) == 0;
    assert len(bindings_for_target(registry, "other")) == 1;
}


test "find_orphan_bindings detects stale target" {
    registry = BindingRegistry();
    subscribe(registry, "session.events", "live-target", "TranscriptChanged");
    subscribe(registry, "session.phase", "stale-target", "PhaseChanged");

    live: set[str] = set();
    live.add("live-target");
    orphans = find_orphan_bindings(registry, live);
    assert len(orphans) == 1;
    assert orphans[0].target_id == "stale-target";
    assert orphans[0].source_id == "session.phase";
    assert orphans[0].event_type == "PhaseChanged";
}


test "dump_bindings returns deterministic ordering" {
    registry = BindingRegistry();
    subscribe(registry, "b.source", "z-target", "ZEvent");
    subscribe(registry, "a.source", "b-target", "BEvent");
    subscribe(registry, "a.source", "a-target", "AEvent");

    dump1 = dump_bindings(registry);
    dump2 = dump_bindings(registry);
    assert dump1 == dump2;
    assert dump1
        == [
            {"source_id": "a.source", "target_id": "a-target", "event_type": "AEvent",},
            {"source_id": "a.source", "target_id": "b-target", "event_type": "BEvent",},
            {"source_id": "b.source", "target_id": "z-target", "event_type": "ZEvent",},

        ];
}


test "clear_bindings empties registry" {
    registry = BindingRegistry();
    subscribe(registry, "session.events", "target-1", "TranscriptChanged");
    subscribe(registry, "session.phase", "target-2", "PhaseChanged");
    clear_bindings(registry);
    assert is_empty(registry);
    assert binding_count(registry) == 0;
    assert len(dump_bindings(registry)) == 0;
}


test "subscribe rejects empty source or target ids" {
    registry = BindingRegistry();
    failed = False;
    try {
        subscribe(registry, "", "target-1", "TranscriptChanged");
    } except ValueError {
        failed = True;
    }
    assert failed;
    failed = False;
    try {
        subscribe(registry, "session.events", "", "TranscriptChanged");
    } except ValueError {
        failed = True;
    }
    assert failed;
    assert is_empty(registry);
}
