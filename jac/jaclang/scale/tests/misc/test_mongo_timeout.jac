"""An unreachable MONGODB_URI must fail fast instead of hanging (#7518).

pymongo's server selection defaults to 30s and MongoClient() itself is lazy,
so the cost lands on the first real round-trip. MongoBackend.postinit made
three of them unconditionally, which is why `jac run hello.jac` blocked
indefinitely with nothing but the banner when a stale MONGODB_URI was
exported in a shell profile."""

import os;
import time;
import from jaclang.scale.config.config_loader { JacScaleConfig }
import from jaclang.scale._optdeps.pymongo { HAS_PYMONGO }
import from jaclang.scale.memory.memory_hierarchy { MongoBackend, _process_cache }


"""An address in TEST-NET-1 (RFC 5737), guaranteed not to be routable."""
glob _DEAD_URI: str = "mongodb://192.0.2.1:27017";


def _clear_mongo_cache {
    for key in ["mongo_client", "mongo_available"] {
        _process_cache.pop(key, None);
    }
}


test "database config exposes a bounded mongodb timeout by default" {
    saved = os.environ.pop("MONGODB_TIMEOUT_MS", None);
    try {
        cfg = JacScaleConfig().get_database_config();
        assert cfg["mongodb_timeout_ms"] == 5000;
    } finally {
        if saved is not None {
            os.environ["MONGODB_TIMEOUT_MS"] = saved;
        }
    }
}


test "MONGODB_TIMEOUT_MS overrides the default probe budget" {
    saved = os.environ.get("MONGODB_TIMEOUT_MS");
    os.environ["MONGODB_TIMEOUT_MS"] = "250";
    try {
        cfg = JacScaleConfig().get_database_config();
        assert cfg["mongodb_timeout_ms"] == 250;
    } finally {
        if saved is None {
            os.environ.pop("MONGODB_TIMEOUT_MS", None);
        } else {
            os.environ["MONGODB_TIMEOUT_MS"] = saved;
        }
    }
}


test "an unreachable mongo resolves unavailable within the probe budget" {
    if not HAS_PYMONGO {
        return;
    }
    saved = os.environ.get("MONGODB_TIMEOUT_MS");
    os.environ["MONGODB_TIMEOUT_MS"] = "500";
    _clear_mongo_cache();
    try {
        start = time.monotonic();
        backend = MongoBackend(mongo_url=_DEAD_URI);
        available = backend.is_available();
        elapsed = time.monotonic() - start;
        assert not available;
        # Pre-fix this was three unbounded round-trips at pymongo's 30s
        # default, so construction alone blocked for 90s. The bound is loose
        # because it covers connect plus probe on a loaded CI box; anything
        # in this range proves the timeout is applied at all.
        assert elapsed < 10.0 , f"MongoBackend blocked {elapsed:.1f}s on an unreachable URI";
    } finally {
        _clear_mongo_cache();
        if saved is None {
            os.environ.pop("MONGODB_TIMEOUT_MS", None);
        } else {
            os.environ["MONGODB_TIMEOUT_MS"] = saved;
        }
    }
}


test "a failed probe is memoized per instance, not re-paid per call" {
    if not HAS_PYMONGO {
        return;
    }
    saved = os.environ.get("MONGODB_TIMEOUT_MS");
    os.environ["MONGODB_TIMEOUT_MS"] = "500";
    _clear_mongo_cache();
    try {
        backend = MongoBackend(mongo_url=_DEAD_URI);
        start = time.monotonic();
        for _ in range(5) {
            assert not backend.is_available();
        }
        elapsed = time.monotonic() - start;
        # postinit already probed, so these five calls must be free. Without
        # the memo each one re-pays server selection: the negative result was
        # written to _process_cache but never read back.
        assert elapsed < 1.0 , f"repeat is_available() re-probed for {elapsed:.1f}s";
    } finally {
        _clear_mongo_cache();
        if saved is None {
            os.environ.pop("MONGODB_TIMEOUT_MS", None);
        } else {
            os.environ["MONGODB_TIMEOUT_MS"] = saved;
        }
    }
}
