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


def pool_enabled -> bool {
    return os.environ.get('JAC_DB_POOL', '1').strip().lower()
        not in ('0', 'false', 'no', 'off');
}


def _pool_max -> int {
    try {
        return max(0, int(os.environ.get('JAC_DB_POOL_MAX', '16') or 16));
    } except ValueError {
        return 16;
    }
}


def _pool_total_max -> int {
    try {
        return max(0, int(os.environ.get('JAC_DB_POOL_TOTAL_MAX', '48') or 48));
    } except ValueError {
        return 48;
    }
}


def _idle_ttl -> float {
    try {
        return max(1.0, float(os.environ.get('JAC_DB_POOL_IDLE_S', '300') or 300));
    } except ValueError {
        return 300.0;
    }
}


def pool_key(info: any) -> str {
    import hashlib;
    where = info.unix_socket_dir or info.host or '';
    raw: str = str(info.password or '');
    secret = hashlib.sha256(raw.encode('utf-8')).hexdigest()[:16];
    return f"{where}:{info.port}:{info.user}:{info.database}:{secret}";
}


def _sock_gone(conn: any) -> bool {
    import select;
    if getattr(conn, '_closed', False) {
        return True;
    }
    sock = conn?._sock;
    if sock is None {
        return True;
    }
    try {
        return bool(select.select([sock], [], [], 0)[0]);
    } except Exception {
        return True;
    }
}


def _discard(conn: any) {
    try {
        conn.close();
    } except Exception {}
}


def checkout(info: any) -> (any | None) {
    if not pool_enabled() {
        return None;
    }
    key = pool_key(info);
    ttl = _idle_ttl();
    now = time.monotonic();
    while True {
        with _lock {
            bucket = _pools.get(key);
            if not bucket {
                return None;
            }
            (conn, parked_at) = bucket.pop();
        }
        if now - parked_at > ttl or _sock_gone(conn) {
            _discard(conn);
            continue;
        }
        return conn;
    }
}


def release(info: any, conn: any) -> None {
    if conn is None {
        return;
    }
    if not pool_enabled() or getattr(conn, '_closed', False) {
        _discard(conn);
        return;
    }
    key = pool_key(info);
    now = time.monotonic();
    ttl = _idle_ttl();
    overflow: (any | None) = None;
    with _lock {
        bucket = _pools.setdefault(key, []);
        kept = [
            item
            for item in bucket
            if now - item[1] <= ttl
        ];
        expired = [
            item[0]
            for item in bucket
            if now - item[1] > ttl
        ];
        if len(kept) >= _pool_max() {
            overflow = conn;
        } else {
            kept.append((conn, now));
        }
        _pools[key] = kept;
        evicted = _evict_oldest_locked(_pool_total_max());
    }
    for old in expired {
        _discard(old);
    }
    for old in evicted {
        _discard(old);
    }
    if overflow is not None {
        _discard(overflow);
    }
}


def _evict_oldest_locked(keep: int) -> list {
    total = sum(len(bucket) for bucket in _pools.values());
    if total <= keep {
        return [];
    }
    parked: list[tuple[float, str, any]] = [
        (at, key, conn) for (key, bucket) in _pools.items() for (conn, at) in bucket
    ];
    parked.sort(key=lambda (item: tuple[float, str, any]) { item[0]; });
    doomed = parked[:total - keep];
    victims: set[int] = {id(conn) for (_at, _key, conn) in doomed};
    for key in list(_pools.keys()) {
        remaining = [
            item
            for item in _pools[key]
            if id(item[0]) not in victims
        ];
        if remaining {
            _pools[key] = remaining;
        } else {
            _pools.pop(key, None);
        }
    }
    return [conn for (_at, _key, conn) in doomed];
}


def drain_all {
    with _lock {
        buckets = list(_pools.values());
        _pools.clear();
    }
    for bucket in buckets {
        for (conn, _at) in bucket {
            _discard(conn);
        }
    }
}


def forget_all {
    with _lock {
        buckets = list(_pools.values());
        _pools.clear();
    }
    for bucket in buckets {
        for (conn, _at) in bucket {
            detach(conn);
        }
    }
}


def detach(conn: any) -> None {
    if conn is None {
        return;
    }
    try {
        conn._closed = True;
        sock = conn?._sock;
        if sock is not None {
            sock.detach();
        }
        conn._sock = None;
    } except Exception {}
}


def _before_fork {
    drain_all();
}


def _after_fork_in_child {
    _lock = threading.Lock();
    forget_all();
}


with entry {
    if hasattr(os, 'register_at_fork') {
        os.register_at_fork(before=_before_fork, after_in_child=_after_fork_in_child);
    }
}


def pool_stats -> dict[str, int] {
    with _lock {
        return {key: len(bucket) for (key, bucket) in _pools.items()};
    }
}
