"""Behavior tests for PgEventStream consumer-group positioning (issue #8047).

PgEventStream.consume shipped without the start_from parameter its interface
declares, so every caller written against EventStreamBroker raised TypeError on
Postgres while working fine on LocalEventStream. Consumers wrap consume() in a
try/except, so the TypeError read as a transient broker hiccup and the stream
went silently dead: 423 published rows, 0 delivered events.

These drive a real embedded Postgres: a new group asking for earliest replays
everything retained, the group cursor advances so a repeat drain is empty, a
second new group replays independently, and latest on a new group skips what
was already published while still delivering what comes after.
"""

import threading;
import uuid;
import from jaclang.runtimelib.pgembed { PgRuntime }
import from jaclang.runtimelib.session { shared_pg_data_dir }
import from jaclang.runtimelib.store { PgStore }
import from jaclang.scale.events.broker { Event }
import from jaclang.scale.events.streams.postgres { PgEventStream, _STREAM_SCHEMA }

glob _holder: dict = {};


"""Fresh stream on the shared embedded cluster, or None when it is unavailable."""
def _stream -> (PgEventStream | None) {
    try {
        if "rt" not in _holder {
            _holder["rt"] = PgRuntime(
                data_dir=shared_pg_data_dir(), database="jac_pg_event_stream"
            );
        }
        store = PgStore(conninfo=_holder["rt"].ensure());
        for stmt in _STREAM_SCHEMA {
            store.rows(stmt, {});
        }
        return PgEventStream(_store=store);
    } except Exception as e {
        print(f"[skip] embedded postgres unavailable: {e}");
        return None;
    }
}


"""Topic nobody else has written to, so offsets start clean every run."""
def _topic -> str {
    return f"jc.test.{uuid.uuid4().hex[:12]}";
}


def _publish(stream: PgEventStream, topic: str, count: int) {
    for n in range(count) {
        stream.publish(topic, Event(event_type="tick", data={"n": n}));
    }
}


test "start_from earliest replays everything a new group missed" {
    stream = _stream();
    if stream is None {
        return;
    }
    topic = _topic();
    try {
        _publish(stream, topic, 3);
        got = stream.consume(
            topic,
            group="g_earliest",
            max_messages=10,
            timeout_seconds=0.0,
            start_from="earliest"
        );
        assert len(got) == 3 , f"earliest replayed {len(got)} of 3 events";
        assert [e.data["n"] for e in got] == [0, 1, 2];
    } finally {
        stream.stop(drain=False);
    }
}


test "the group cursor advances so a repeat drain is empty" {
    stream = _stream();
    if stream is None {
        return;
    }
    topic = _topic();
    try {
        _publish(stream, topic, 3);
        first = stream.consume(
            topic,
            group="g_cursor",
            max_messages=10,
            timeout_seconds=0.0,
            start_from="earliest"
        );
        assert len(first) == 3;
        again = stream.consume(
            topic,
            group="g_cursor",
            max_messages=10,
            timeout_seconds=0.0,
            start_from="earliest"
        );
        assert again == [] , f"cursor did not advance, redelivered {len(again)}";
    } finally {
        stream.stop(drain=False);
    }
}


test "a second new group replays independently of the first" {
    stream = _stream();
    if stream is None {
        return;
    }
    topic = _topic();
    try {
        _publish(stream, topic, 2);
        first = stream.consume(
            topic,
            group="g_one",
            max_messages=10,
            timeout_seconds=0.0,
            start_from="earliest"
        );
        second = stream.consume(
            topic,
            group="g_two",
            max_messages=10,
            timeout_seconds=0.0,
            start_from="earliest"
        );
        assert len(first) == 2;
        assert len(second) == 2 , f"second group got {len(second)} of 2 events";
        assert [e.id for e in first] == [e.id for e in second];
    } finally {
        stream.stop(drain=False);
    }
}


test "start_from latest bookmarks a new group past published events" {
    stream = _stream();
    if stream is None {
        return;
    }
    topic = _topic();
    try {
        _publish(stream, topic, 2);
        skipped = stream.consume(
            topic,
            group="g_latest",
            max_messages=10,
            timeout_seconds=0.0,
            start_from="latest"
        );
        assert skipped == [] , f"latest replayed {len(skipped)} prior events";

        stream.publish(topic, Event(event_type="tick", data={"n": 99}));
        fresh = stream.consume(
            topic,
            group="g_latest",
            max_messages=10,
            timeout_seconds=0.0,
            start_from="latest"
        );
        assert len(fresh) == 1 , f"latest group got {len(fresh)} of 1 new event";
        assert fresh[0].data["n"] == 99;
    } finally {
        stream.stop(drain=False);
    }
}


test "register_handler shares the same positioning rule as consume" {
    stream = _stream();
    if stream is None {
        return;
    }
    topic = _topic();
    received: list[Event] = [];
    done = threading.Event();

    def handler(ev: Event) {
        received.append(ev);
        done.set();
    }
    try {
        _publish(stream, topic, 1);
        stream.register_handler(topic, handler, group="g_push", start_from="earliest");
        assert done.`wait(timeout=15.0) , "handler never received the replayed event";
        assert received[0].data["n"] == 0;
    } finally {
        stream.stop(drain=False);
    }
}


test "start_from is a one-time bookmark, not a per-call rewind" {
    stream = _stream();
    if stream is None {
        return;
    }
    topic = _topic();
    try {
        _publish(stream, topic, 2);
        drained = stream.consume(
            topic,
            group="g_bookmark",
            max_messages=10,
            timeout_seconds=0.0,
            start_from="earliest"
        );
        assert len(drained) == 2;
        stream.publish(topic, Event(event_type="tick", data={"n": 7}));
        tail = stream.consume(
            topic,
            group="g_bookmark",
            max_messages=10,
            timeout_seconds=0.0,
            start_from="latest"
        );
        assert len(tail) == 1 , f"stored position ignored, got {len(tail)} events";
        assert tail[0].data["n"] == 7;
    } finally {
        stream.stop(drain=False);
    }
}
