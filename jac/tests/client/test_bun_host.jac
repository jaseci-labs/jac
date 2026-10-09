import os;
import from pathlib { Path }
import from jaclang.jac0core.host {
    HOST_BUN,
    HOST_CAPABILITIES,
    framework_for_host_kind,
    host_provides_kind
}
import from jaclang.jac0core.sv_service_host { resolve_sv_service_host }
import from jaclang.server.sv_client { sv_host_env_key }
import from jaclang.compiler.backends.es.backends.registry { resolve_framework_backend }


test "bun host provides NPM, JS_GLOBALS, and PERSIST but not DOM" {
    assert host_provides_kind(HOST_BUN, 'NPM');
    assert host_provides_kind(HOST_BUN, 'JS_GLOBALS');
    assert host_provides_kind(HOST_BUN, 'PERSIST');
    assert not host_provides_kind(HOST_BUN, 'DOM');
    assert HOST_CAPABILITIES[HOST_BUN] == ['NPM', 'JS_GLOBALS', 'PERSIST'];
}

test "framework_for_host_kind maps bun to bun backend" {
    assert framework_for_host_kind(HOST_BUN) == 'bun';
    backend = resolve_framework_backend('bun');
    assert backend.name() == 'bun';
    assert backend.runtime_source_basename() == 'server_runtime.jac';
}

test "resolve_sv_service_host honors JAC_SV_*_HOST env override" {
    key = sv_host_env_key('demo_svc');
    prev = os.environ.get(key, '');
    os.environ[key] = 'bun';
    try {
        assert resolve_sv_service_host('demo_svc', '.') == 'bun';
    } finally {
        if prev {
            os.environ[key] = prev;
        } else {
            del os.environ[key];
        }
    }
}

test "bun target is registered in the host factory" {
    import from jaclang.client.targets.registry { get_host_factory }
    factory = get_host_factory();
    names = factory.get_available_host_names();
    assert 'bun' in names;
    assert 'test' in names;
}
