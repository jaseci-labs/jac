impl PodCache.postinit -> None {
    self._rows = OrderedDict();
    self._lock = threading.RLock();
    self.hits = 0;
    self.misses = 0;
}


impl PodCache.get(ns: str, id: UUID, version: int) -> (Any | None) {
    with self._lock {
        key = (ns, id);
        entry = self._rows.get(key);
        if entry is None or entry[0] != version {
            self.misses += 1;
            return None;
        }
        self._rows.move_to_end(key);
        self.hits += 1;
        return entry[1];
    }
}


impl PodCache.put(ns: str, id: UUID, version: int, payload: Any) -> None {
    with self._lock {
        key = (ns, id);
        self._rows[key] = (version, payload);
        self._rows.move_to_end(key);
        while len(self._rows) > self.capacity {
            self._rows.popitem(last=False);
        }
    }
}


impl PodCache.invalidate(ns: str, id: UUID) -> None {
    with self._lock {
        self._rows.pop((ns, id), None);
    }
}


impl PodCache.invalidate_payload(ns: str, payload: str) -> None {
    for part in payload.split(',') {
        token = part.strip();
        if not token {
            continue;
        }
        try {
            self.invalidate(ns, UUID(token));
        } except ValueError {
            logger.debug(f"PodCache: ignoring malformed invalidation {token!r}");
        }
    }
}


impl PodCache.clear -> None {
    with self._lock {
        self._rows.clear();
    }
}
