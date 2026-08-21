"""P3 acceptance tests for jaseci-labs/jac#8144 (JS host registry rows).

Derived from PLAN.md Priority 3 only — not from implementation internals.
P3 adds web-worker, service-worker, edge, and cli-js as Host registry rows
without shipping build/dev/start features yet.
"""

import from pathlib { Path }
import from tests.support { JAC_ROOT }
import from jaclang.jac0core.host {
    HOST_CAPABILITIES,
    HOST_CLI_JS,
    HOST_DOM,
    HOST_EDGE,
    HOST_JS_GLOBALS,
    HOST_NPM,
    HOST_PERSIST,
    HOST_SERVICE_WORKER,
    HOST_WEB_WORKER,
    P3_JS_HOST_CAPS,
    P3_JS_HOST_KINDS,
    TARGET_HOST_KIND,
    host_kind_for_target,
    host_provides_kind
}
import from jaclang.runtimelib.client.targets.registry {
    get_host_factory,
    get_host_registry
}


glob _TARGETS_DIR: Path = (
    Path(JAC_ROOT) / 'jaclang' / 'runtimelib' / 'client' / 'targets'
);


test "P3 JS host kinds advertise NPM and JS_GLOBALS only" {
    for kind in P3_JS_HOST_KINDS {
        assert HOST_CAPABILITIES[kind] == P3_JS_HOST_CAPS;
        assert host_provides_kind(kind, HOST_NPM) , f"{kind} must provide NPM";
        assert host_provides_kind(kind, HOST_JS_GLOBALS) , (
            f"{kind} must provide JS_GLOBALS"
        );
        assert not host_provides_kind(kind, HOST_DOM) , f"{kind} must not provide DOM";
        assert not host_provides_kind(kind, HOST_PERSIST) , (
            f"{kind} must not provide PERSIST until its host has a Store"
        );
    }
}

test "P3_JS_HOST_KINDS lists the four registry rows" {
    assert P3_JS_HOST_KINDS == (
        HOST_WEB_WORKER,
        HOST_SERVICE_WORKER,
        HOST_EDGE,
        HOST_CLI_JS
    );
}

test "target aliases resolve to P3 host kinds via TARGET_HOST_KIND" {
    assert host_kind_for_target('web-worker') == HOST_WEB_WORKER;
    assert host_kind_for_target('worker') == HOST_WEB_WORKER;
    assert host_kind_for_target('service-worker') == HOST_SERVICE_WORKER;
    assert host_kind_for_target('sw') == HOST_SERVICE_WORKER;
    assert host_kind_for_target('edge') == HOST_EDGE;
    assert host_kind_for_target('cloudflare') == HOST_EDGE;
    assert host_kind_for_target('cloudflare-workers') == HOST_EDGE;
    assert host_kind_for_target('cli-js') == HOST_CLI_JS;
    assert host_kind_for_target('cli_js') == HOST_CLI_JS;
    assert TARGET_HOST_KIND['worker'] == HOST_WEB_WORKER;
    assert TARGET_HOST_KIND['sw'] == HOST_SERVICE_WORKER;
    assert TARGET_HOST_KIND['cloudflare-workers'] == HOST_EDGE;
}

test "HostFactory exposes P3 registry row names" {
    factory = get_host_factory();
    names = factory.get_available_host_names();
    for row in P3_JS_HOST_KINDS {
        assert row in names , f"missing P3 registry row {row!r}";
    }
}

test "HostFactory resolves P3 rows and rejects build as registry-only" {
    registry = get_host_registry();
    factory = get_host_factory();
    for row in P3_JS_HOST_KINDS {
        host = factory.create(row, _TARGETS_DIR.parent.parent);
        assert host.host_kind == row;
        assert registry.get(row) is not None;
        try {
            host.build(_TARGETS_DIR / 'register.jac', _TARGETS_DIR.parent.parent);
            assert False , f"{row} build should stay unimplemented in P3";
        } except NotImplementedError as exc {
            assert 'registry row only' in str(exc);
        }
    }
}
