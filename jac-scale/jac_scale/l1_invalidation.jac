"""Cross-pod L1 cache invalidation via Redis pub/sub (issue #6313).

After an authoritative anchor write, the writer broadcasts an eviction; a single
process-wide listener drops that anchor from every *other* active L1, so sibling
pods/contexts reload the merged value from L3 instead of serving a stale copy.

- Self-suppression is keyed by L1 instance, not pod: the writer keeps its own
  fresh entry while same-process sibling contexts are still evicted.
- The listener owns its connection, re-subscribes with capped backoff after a
  Redis drop, and never busy-spins.
- The registry holds L1s weakly, keyed by a stable uuid, so a context that skips
  close() can't leak its __mem__.
"""

import json;
import logging;
import threading;
import weakref;
import from typing { Any, cast }
import from uuid { UUID, uuid4 }
import from jac_scale._optdeps.redis { redis_module as redis }

glob logger = logging.getLogger(__name__),
     DEFAULT_INVALIDATION_CHANNEL = "jac:anchor:invalidate",
     # l1_id -> owning ScaleTieredMemory, held weakly. RLock guards the registry
     # and the snapshot taken before eviction.
     _l1_registry = weakref.WeakValueDictionary(),
     _l1_lock = threading.RLock();


"""Mint a fresh, process-unique L1 instance id."""
def new_l1_id -> str {
    return uuid4().hex;
}


"""Register an active L1 under its stable id."""
def register_l1(l1_id: str, mem: Any) {
    with _l1_lock {
        _l1_registry[l1_id] = mem;
    }
}


"""Deregister an L1 on close (GC also reclaims it via the weak reference)."""
def deregister_l1(l1_id: str) {
    with _l1_lock {
        _l1_registry.pop(l1_id, None);
    }
}


"""Evict `anchor_id` from every active L1 except `origin_l1_id`; return the count
evicted. dict.pop is atomic under the GIL, so we hold the lock only to snapshot
the registry, not while mutating each __mem__."""
def evict_local_l1(anchor_id: str, origin_l1_id: (str | None) = None) -> int {
    try {
        key = UUID(anchor_id);
    } except Exception {
        return 0;
    }
    with _l1_lock {
        targets = [
            mem
            for (lid, mem) in list(_l1_registry.items())
            if lid != origin_l1_id
        ];
    }
    evicted = 0;
    for mem in targets {
        try {
            if mem.__mem__.pop(key, None) is not None {
                evicted += 1;
            }
        } except Exception { }
    }
    return evicted;
}


"""Parse one pub/sub payload and evict the named anchor from sibling L1s."""
def _handle_message(data: Any) {
    try {
        text = data.decode("utf-8") if isinstance(data, (bytes, bytearray)) else data;
        payload = json.loads(cast(str, text));
        anchor_id = cast(str, payload.get("a") or "");
        origin = cast((str | None), payload.get("o"));
        if anchor_id {
            evict_local_l1(anchor_id, origin);
        }
    } except Exception as e {
        logger.debug(f"L1 invalidation: dropping malformed message: {e}");
    }
}


"""Serialize an invalidation message: anchor id + originating L1 id."""
def build_message(anchor_id: str, origin_l1_id: (str | None)) -> str {
    return json.dumps({"a": anchor_id, "o": origin_l1_id});
}


"""Process-wide listener: subscribes on a daemon thread and evicts named anchors
from sibling L1s, self-healing across Redis drops with capped backoff."""
obj L1InvalidationListener {
    has redis_url: str,
        channel: str,
        _stop: Any by postinit,
        _thread: Any by postinit;

    def postinit {
        self._stop = threading.Event();
        self._thread = threading.Thread(
            target=self._run, name="jac-l1-invalidation", daemon=True
        );
    }

    def start {
        self._thread.start();
    }

    def is_alive -> bool {
        return bool(self._thread.is_alive());
    }

    def stop {
        self._stop.set();
    }

    def join(timeout: float) {
        self._thread.join(timeout);
    }

    def _run {
        r = cast(Any, redis);
        backoff = 0.5;
        max_backoff = 30.0;
        while not self._stop.is_set() {
            pubsub: Any = None;
            client: Any = None;
            try {
                client = r.from_url(self.redis_url);
                pubsub = client.pubsub(ignore_subscribe_messages=True);
                pubsub.subscribe(self.channel);
                backoff = 0.5;  # reset after a clean (re)subscribe
                while not self._stop.is_set() {
                    msg = pubsub.get_message(timeout=1.0);
                    if msg is not None and msg.get("type") == "message" {
                        _handle_message(msg.get("data"));
                    }
                }
            } except Exception as e {
                # Connection dropped: back off on the stop Event (prompt
                # shutdown, no busy-spin), then re-subscribe.
                logger.debug(f"L1 invalidation listener reconnecting: {e}");
                self._stop.wait(backoff);
                backoff = min(backoff * 2, max_backoff);
            } finally {
                if pubsub is not None {
                    try {
                        pubsub.close();
                    } except Exception { }
                }
                if client is not None {
                    try {
                        client.close();
                    } except Exception { }
                }
            }
        }
    }
}


"""Start the process-wide listener once (idempotent, thread-safe). A dead handle
is replaced so the process self-recovers. No-op when redis is unavailable."""
def ensure_listener(
    process_cache: dict, redis_url: (str | None), channel: str
) -> None {
    if redis is None or not redis_url {
        return;
    }
    with _l1_lock {
        existing = process_cache.get("l1_listener");
        if existing is not None and existing.is_alive() {
            return;
        }
        listener = L1InvalidationListener(redis_url, channel);
        process_cache["l1_listener"] = listener;
        listener.start();
    }
}


"""Stop the process-wide listener (teardown / test isolation)."""
def stop_listener(process_cache: dict) {
    with _l1_lock {
        listener = process_cache.pop("l1_listener", None);
    }
    if listener is not None {
        try {
            listener.stop();
            listener.join(timeout=2.0);
        } except Exception { }
    }
}
