import json;
import logging;
import threading;
import weakref;
import from typing { cast }
import from uuid { UUID, uuid4 }
import from jaclang.scale._optdeps.redis { redis_module as redis }
import from jaclang.runtimelib.memory { VolatileMemory }

glob logger = logging.getLogger(__name__),
     DEFAULT_INVALIDATION_CHANNEL = "jac:anchor:invalidate",
     _l1_registry = weakref.WeakValueDictionary(),
     _stale_marks: dict[str, set[UUID]] = {},
     _l1_lock = threading.RLock();


def new_l1_id -> str {
    return uuid4().hex;
}


def register_l1(l1_id: str, mem: VolatileMemory) {
    with _l1_lock {
        _l1_registry[l1_id] = mem;
    }
    weakref.finalize(mem, deregister_l1, l1_id);
}


def deregister_l1(l1_id: str) {
    with _l1_lock {
        _l1_registry.pop(l1_id, None);
        _stale_marks.pop(l1_id, None);
    }
}


def evict_local_l1(anchor_id: str, origin_l1_id: (str | None) = None) -> int {
    try {
        key = UUID(anchor_id);
    } except Exception {
        return 0;
    }
    with _l1_lock {
        targets = [
            (cast(str, lid), cast(VolatileMemory, mem))
            for (lid, mem) in list(_l1_registry.items())
            if lid != origin_l1_id
        ];
    }
    to_mark: list[str] = [];
    for (sid, mem) in targets {
        try {
            if key in mem.__mem__ {
                to_mark.append(sid);
            }
        } except Exception { }
    }
    if not to_mark {
        return 0;
    }
    with _l1_lock {
        for sid in to_mark {
            marks = _stale_marks.get(sid);
            if marks is None {
                marks = set();
                _stale_marks[sid] = marks;
            }
            marks.add(key);
        }
    }
    return len(to_mark);
}


def consume_stale(l1_id: str, id: UUID) -> bool {
    marks = _stale_marks.get(l1_id);
    if marks is None or id not in marks {
        return False;
    }
    with _l1_lock {
        marks = _stale_marks.get(l1_id);
        if marks is not None and id in marks {
            marks.discard(id);
            if not marks {
                _stale_marks.pop(l1_id, None);
            }
            return True;
        }
    }
    return False;
}


def _handle_message(data: (bytes | str)) {
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


def build_message(anchor_id: str, origin_l1_id: (str | None)) -> str {
    return json.dumps({"a": anchor_id, "o": origin_l1_id});
}


obj L1InvalidationListener {
    has redis_url: str,
        channel: str,
        _stop: threading.Event by postinit,
        _thread: threading.Thread by postinit;

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
        r = cast(any, redis);
        backoff = 0.5;
        max_backoff = 30.0;
        while not self._stop.is_set() {
            pubsub: any = None;
            client: any = None;
            try {
                client = r.from_url(self.redis_url);
                pubsub = client.pubsub(ignore_subscribe_messages=True);
                pubsub.subscribe(self.channel);
                backoff = 0.5;
                while not self._stop.is_set() {
                    msg = pubsub.get_message(timeout=1.0);
                    if msg is not None and msg.get("type") == "message" {
                        _handle_message(cast((bytes | str), msg.get("data")));
                    }
                }
            } except Exception as e {
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


def ensure_listener(
    process_cache: dict[str, any], redis_url: (str | None), channel: str
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


def stop_listener(process_cache: dict[str, any]) {
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
