import logging;
import threading;
import from collections.abc { Generator }
import from uuid { UUID }

import from jaclang.runtime.archetype { Anchor, Root }

glob logger = logging.getLogger(__name__),
     __all__ = ['Memory'];


obj Memory {
    has base_path: (str | None) = None,
        target_path: (str | None) = None,
        __mem__: dict[UUID, Anchor] postinit,
        _dirty: dict[UUID, None] postinit,
        _deleted: set[UUID] postinit,
        _on_commit: list[Callable] postinit,
        _lock: threading.RLock postinit;

    has store: (any | None) {
        getter {
            return None;
        }
    }

    def postinit {
        self._init_memory();
    }

    def _init_memory {
        self._lock = threading.RLock();
        self.__mem__ = {};
        self._dirty = {};
        self._deleted = set();
        self._on_commit = [];
    }

    def is_available -> bool {
        return True;
    }

    def data_location -> (str | None) {
        return None;
    }

    def get(id: UUID) -> (Anchor | None) {
        if id in self._deleted {
            return None;
        }
        return self.__mem__.get(id);
    }

    def put(anchor: Anchor) {
        aid = anchor.ensure_id();
        with self._lock {
            self.__mem__[aid] = anchor;
            self._dirty[aid] = None;
            self._deleted.discard(aid);
        }
    }

    def mark_dirty(anchor: Anchor) {
        if anchor.id in self.__mem__ {
            self._dirty[anchor.id] = None;
        }
    }

    def delete(id: UUID) {
        with self._lock {
            self.__mem__.pop(id, None);
            self._dirty.pop(id, None);
            self._deleted.add(id);
        }
    }

    def `has(id: UUID) -> bool {
        if id in self._deleted {
            return False;
        }
        return id in self.__mem__;
    }

    def query(
        filter: (Callable[[Anchor], bool] | None) = None
    ) -> Generator[Anchor, None, None] {
        for anchor in list(self.__mem__.values()) {
            if filter is None or filter(anchor) {
                yield anchor;
            }
        }
    }

    def get_roots -> Generator[Root, None, None] {
        for anchor in list(self.__mem__.values()) {
            if isinstance(anchor.archetype, Root) {
                yield anchor.archetype;
            }
        }
    }

    def find(
        ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
    ) -> Generator[Anchor, None, None] {
        id_list = [ids] if isinstance(ids, UUID) else list(ids);
        for id in id_list {
            if (anchor := self.get(id)) {
                if filter is None or filter(anchor) {
                    yield anchor;
                }
            }
        }
    }

    def find_one(
        ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
    ) -> (Anchor | None) {
        return next(self.find(ids, filter), None);
    }

    def batch_get(ids: list[UUID]) -> dict[UUID, Anchor] {
        out: dict[UUID, Anchor] = {};
        for i in ids {
            if i in self._deleted {
                continue;
            }
            if (hit := self.__mem__.get(i)) is not None {
                out[i] = hit;
            }
        }
        return out;
    }

    def commit(anchor: (Anchor | None) = None) {
        with self._lock {
            self._dirty.clear();
            self._deleted.clear();
        }
        self._fire_on_commit();
    }

    def abort {
        self._dirty.clear();
        self._deleted.clear();
        self._on_commit = [];
    }

    def get_mem -> dict[UUID, Anchor] {
        return self.__mem__;
    }

    def quarantine_ref(referrer: (Anchor | None), stub: Anchor) {
        self.__mem__.pop(stub.ensure_id(), None);
    }

    def is_recoverable_quarantine(id: UUID) -> bool {
        return False;
    }

    async def aget(id: UUID) -> (Anchor | None) {
        return self.get(id);
    }

    async def aput(anchor: Anchor) {
        self.put(anchor);
    }

    async def adelete(id: UUID) {
        self.delete(id);
    }

    async def ahas(id: UUID) -> bool {
        return self.`has(id);
    }

    async def acommit(anchor: (Anchor | None) = None) {
        self.commit(anchor);
    }

    def on_commit(callback: Callable) {
        self._on_commit.append(callback);
    }

    def _fire_on_commit {
        fired = self._on_commit;
        self._on_commit = [];
        for cb in fired {
            try {
                cb();
            } except Exception as e {
                logger.warning(f"on_commit callback failed: {type(e).__name__}: {e}");
            }
        }
    }

    def read_barrier {}
    def flush(full: bool = False) {}
    def reset_fetch_count {}
    def get_fetch_count -> int {
        return 0;
    }

    def unit_enter(key: (str | None) = None) {}
    def unit_exit {}
    def unit_depth -> int {
        return 0;
    }

    def read_scope_enter {}
    def read_scope_exit {}
    def run_request(body: Callable) -> any {
        result = body();
        self.commit();
        return result;
    }

    def close {
        self.commit();
        self.__mem__.clear();
        self._dirty.clear();
        self._deleted.clear();
    }
}
