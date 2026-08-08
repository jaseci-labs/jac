import logging;
import threading;
import from collections { OrderedDict }
import from typing { Any }
import from uuid { UUID }

glob logger = logging.getLogger(__name__),
     INVALIDATION_CHANNEL = 'jac_anchor_inval',
     DEFAULT_CAPACITY = 4096,
     __all__ = ['PodCache', 'INVALIDATION_CHANNEL'];


obj PodCache {
    has capacity: int = DEFAULT_CAPACITY,
        _rows: OrderedDict postinit,
        _lock: threading.RLock postinit,
        hits: int postinit,
        misses: int postinit;

    def postinit -> None;
    def get(ns: str, id: UUID, version: int) -> (Any | None);
    def put(ns: str, id: UUID, version: int, payload: Any) -> None;
    def invalidate(ns: str, id: UUID) -> None;
    def invalidate_payload(ns: str, payload: str) -> None;
    def clear -> None;
}
