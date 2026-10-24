import logging;
import threading;
import from collections.abc { Generator }
import from uuid { UUID }

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

    def postinit;
    def _init_memory;
    def new_session(target_path: str) -> Memory;
    def is_available -> bool;
    def data_location -> (str | None);
    def get(id: UUID) -> (Anchor | None);
    def put(anchor: Anchor);
    def mark_dirty(anchor: Anchor);
    def delete(id: UUID);
    def `has(id: UUID) -> bool;
    def query(
        filter: (Callable[[Anchor], bool] | None) = None
    ) -> Generator[Anchor, None, None];

    def get_roots -> Generator[Root, None, None];
    def find(
        ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
    ) -> Generator[Anchor, None, None];

    def find_one(
        ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
    ) -> (Anchor | None);

    def batch_get(ids: list[UUID]) -> dict[UUID, Anchor];
    def commit(anchor: (Anchor | None) = None);
    def abort;
    def get_mem -> dict[UUID, Anchor];
    def quarantine_ref(referrer: (Anchor | None), stub: Anchor);
    def preserve_unresolved_ref(id: UUID) -> bool;
    async def aget(id: UUID) -> (Anchor | None);
    async def aput(anchor: Anchor);
    async def adelete(id: UUID);
    async def ahas(id: UUID) -> bool;
    async def acommit(anchor: (Anchor | None) = None);
    def on_commit(callback: Callable);
    def _fire_on_commit;
    def read_barrier;
    def seal_scan;
    def unseal_scan;
    def flush(full: bool = False);
    def reset_fetch_count;
    def get_fetch_count -> int;
    def unit_enter(key: (str | None) = None);
    def unit_exit;
    def unit_depth -> int;
    def take_ro_retry -> str | None;
    def read_scope_enter;
    def read_scope_exit;
    def run_request(body: Callable) -> any;
    def close;
    async def aclose;
}
