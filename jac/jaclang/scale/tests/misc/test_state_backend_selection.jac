"""Where a rate limiter keeps its buckets, and what happens when it cannot.

`get_state_backend` decides between one shared store and one bucket table
per process. That decision used to be gated on a config key no loader
emitted, so a fleet of N replicas silently enforced N times the configured
limit. The key is real now and the shared branch also fires implicitly in a
cluster, so the property worth pinning is not the key name: it is that a
process inside a fleet can never end up with private buckets, and that an
unreachable store is refused out loud rather than absorbed.

The reachable-store arm (a real embedded Postgres answering as
PgStateBackend) needs the deploy tier and is not here; see
`jac/jaclang/scale/tests/TESTING.md`.
"""

import os;
import jaclang.scale.state.factory as factory_mod;
import jaclang.server.shared_store as store_mod;
import from jaclang.scale.state.factory { get_state_backend, in_fleet }
import from jaclang.scale.state.state_backend { InProcessStateBackend }

glob _CLUSTER_ENV = 'KUBERNETES_SERVICE_HOST',
     _SIBLING_ENV = 'JAC_SV_SIBLING',
     _DB_ENV = 'JAC_DB_URL',
     _DEAD_URL = 'postgresql://jac:jac@127.0.0.1:1/jac';


def _reset {
    factory_mod._backend_holder.clear();
    store_mod._holder.clear();
}


def _set_env(pairs: dict[str, str | None]) -> dict[str, str | None] {
    previous: dict[str, str | None] = {};
    for (key, value) in pairs.items() {
        previous[key] = os.environ.get(key);
        if value is None {
            os.environ.pop(key, None);
        } else {
            os.environ[key] = value;
        }
    }
    return previous;
}


test "outside a fleet, unshared state stays in this process" {
    previous = _set_env({_CLUSTER_ENV: None, _SIBLING_ENV: None});
    _reset();
    try {
        assert not in_fleet();
        assert isinstance(get_state_backend(False), InProcessStateBackend);
    } finally {
        _set_env(previous);
        _reset();
    }
}


test "a pod is in the fleet by its own environment, not by a config key" {
    previous = _set_env({_CLUSTER_ENV: '10.96.0.1', _SIBLING_ENV: None});
    try {
        assert in_fleet();
    } finally {
        _set_env(previous);
    }
    previous = _set_env({_CLUSTER_ENV: None, _SIBLING_ENV: '1'});
    try {
        assert in_fleet();
    } finally {
        _set_env(previous);
    }
}


test "shared state with no reachable store is refused, not absorbed" {
    previous = _set_env({_CLUSTER_ENV: None, _SIBLING_ENV: None, _DB_ENV: _DEAD_URL});
    _reset();
    try {
        with testraises(RuntimeError) as exc {
            get_state_backend(True);
        }
        message = str(exc.value);
        assert 'shared state needs a reachable database' in message;
    } finally {
        _set_env(previous);
        _reset();
    }
}


test "a pod never falls back to private buckets, even asking for unshared" {
    previous = _set_env(
        {_CLUSTER_ENV: '10.96.0.1', _SIBLING_ENV: None, _DB_ENV: _DEAD_URL}
    );
    _reset();
    try {
        with testraises(RuntimeError) as exc {
            get_state_backend(False);
        }
        assert 'across a fleet' in str(exc.value);
    } finally {
        _set_env(previous);
        _reset();
    }
}
