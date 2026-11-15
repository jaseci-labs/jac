import logging;
import os;
import threading;
import time;

glob logger = logging.getLogger(__name__),
     _lock = threading.Lock(),
     _pools: dict[str, list[tuple[any, float]]] = {},
     __all__ = [
         'pool_enabled',
         'pool_key',
         'checkout',
         'release',
         'drain_all',
         'forget_all',
         'detach',
         'pool_stats'
     ];


def pool_enabled -> bool;


def _pool_max -> int;


def _pool_total_max -> int;


def _idle_ttl -> float;


def pool_key(info: any) -> str;


def _sock_gone(conn: any) -> bool;


def _discard(conn: any);


def checkout(info: any) -> (any | None);


def release(info: any, conn: any) -> None;


def _evict_oldest_locked(keep: int) -> list[any];


def drain_all;


def forget_all;


def detach(conn: any) -> None;


def _before_fork;


def _after_fork_in_child;


with entry {
    if hasattr(os, 'register_at_fork') {
        os.register_at_fork(before=_before_fork, after_in_child=_after_fork_in_child);
    }
}


def pool_stats -> dict[str, int];
