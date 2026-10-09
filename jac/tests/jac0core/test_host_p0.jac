"""P0 acceptance tests for jaseci-labs/jac#8144 (Host axis, no bun).

Derived from PLAN.md Priority 0 only — not from implementation internals.
"""

import os;
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support { JAC_ROOT }
import from jaclang.compiler.frontend.constant { CodeContext }
import from jaclang.compiler.frontend.codeinfo {
    clear_bun_host_decision_cache,
    project_uses_bun_host
}
import from jaclang.jac0core.host {
    CAPABILITY_CODESPACE,
    CAPABILITY_SEED_ORDER,
    HOST_BARE_METAL,
    HOST_BROWSER,
    HOST_BUN,
    HOST_CAPABILITIES,
    HOST_CLI_JS,
    HOST_CPYTHON,
    HOST_DOM,
    HOST_EDGE,
    HOST_FFI,
    HOST_JS_GLOBALS,
    HOST_NPM,
    HOST_PERSIST,
    HOST_PY,
    HOST_RN,
    HOST_SERVICE_WORKER,
    HOST_WEBVIEW,
    HOST_WEB_WORKER,
    NPM_SEED_REASONS,
    P3_JS_HOST_KINDS,
    TARGET_HOST_KIND,
    codespace_for_capability,
    framework_for_host_kind,
    host_kind_for_target,
    host_provides_kind,
    native_unmet_capability,
    seed_codespace_for_req
}


test "capability table matches PLAN host mapping" {
    assert HOST_CAPABILITIES[HOST_BROWSER] == [HOST_DOM, HOST_NPM, HOST_JS_GLOBALS];
    assert HOST_CAPABILITIES[HOST_WEBVIEW] == [HOST_DOM, HOST_NPM, HOST_JS_GLOBALS];
    assert HOST_CAPABILITIES[HOST_RN] == [HOST_NPM, HOST_JS_GLOBALS];
    assert HOST_CAPABILITIES[HOST_BUN] == [HOST_NPM, HOST_JS_GLOBALS, HOST_PERSIST];
    assert HOST_CAPABILITIES[HOST_CPYTHON] == [HOST_PY, HOST_PERSIST];
    assert HOST_CAPABILITIES[HOST_BARE_METAL] == [HOST_FFI];
}

test "DOM is limited to browser and webview hosts" {
    for kind in [
        HOST_BROWSER,
        HOST_WEBVIEW,
        HOST_RN,
        HOST_BUN,
        *P3_JS_HOST_KINDS,
        HOST_CPYTHON,
        HOST_BARE_METAL
    ] {
        provides_dom = host_provides_kind(kind, HOST_DOM);
        if kind in [HOST_BROWSER, HOST_WEBVIEW] {
            assert provides_dom , f"{kind} must provide DOM";
        } else {
            assert not provides_dom , f"{kind} must not provide DOM";
        }
    }
}

test "NPM covers every JS host in the capability table" {
    js_hosts = [HOST_BROWSER, HOST_WEBVIEW, HOST_RN, HOST_BUN, *P3_JS_HOST_KINDS];
    for kind in js_hosts {
        assert host_provides_kind(kind, HOST_NPM) , f"{kind} must provide NPM";
    }
    assert not host_provides_kind(HOST_CPYTHON, HOST_NPM);
    assert not host_provides_kind(HOST_BARE_METAL, HOST_NPM);
}

test "PY attaches to CPython host; PERSIST on Store hosts" {
    assert host_provides_kind(HOST_CPYTHON, HOST_PY);
    assert host_provides_kind(HOST_CPYTHON, HOST_PERSIST);
    assert host_provides_kind(HOST_BUN, HOST_PERSIST);
    for kind in [HOST_BROWSER, HOST_RN, HOST_BARE_METAL] {
        assert not host_provides_kind(kind, HOST_PY) , f"{kind} must not provide PY";
        assert not host_provides_kind(kind, HOST_PERSIST) , (
            f"{kind} must not provide PERSIST until its host has a Store"
        );
    }
}

test "FFI attaches to bare-metal host only" {
    assert host_provides_kind(HOST_BARE_METAL, HOST_FFI);
    for kind in [HOST_BROWSER, HOST_CPYTHON, HOST_BUN, HOST_RN] {
        assert not host_provides_kind(kind, HOST_FFI);
    }
}

test "capability to codespace lookup replaces signal-node tuples" {
    assert codespace_for_capability(HOST_DOM) == CodeContext.CLIENT;
    assert codespace_for_capability(HOST_NPM) == CodeContext.CLIENT;
    assert codespace_for_capability(HOST_FFI) == CodeContext.NATIVE;
    assert codespace_for_capability(HOST_PY) is None;
    assert CAPABILITY_CODESPACE
        == {
            HOST_FFI: CodeContext.NATIVE,
            HOST_DOM: CodeContext.CLIENT,
            HOST_NPM: CodeContext.CLIENT
        };
}

test "seed_codespace_for_req uses the provider table not cap arm chains" {
    assert CAPABILITY_SEED_ORDER == (HOST_FFI, HOST_DOM, HOST_NPM);
    assert seed_codespace_for_req(HOST_DOM, 'jsx element') == CodeContext.CLIENT;
    assert seed_codespace_for_req(HOST_FFI, 'native anchor') == CodeContext.NATIVE;
    for reason in NPM_SEED_REASONS {
        assert seed_codespace_for_req(HOST_NPM, reason) == CodeContext.CLIENT , (
            f"NPM seed must accept documented reason {reason!r}"
        );
    }
    assert seed_codespace_for_req(HOST_NPM, 'unlisted requirement') is None;
}

test "target names resolve to host kinds via registry table only" {
    assert host_kind_for_target('web') == HOST_BROWSER;
    assert host_kind_for_target('desktop') == HOST_WEBVIEW;
    assert host_kind_for_target('react-native') == HOST_RN;
    assert host_kind_for_target('bun') == HOST_BUN;
    assert host_kind_for_target('server') == HOST_BUN;
    assert host_kind_for_target('worker') == HOST_WEB_WORKER;
    assert host_kind_for_target('sw') == HOST_SERVICE_WORKER;
    assert host_kind_for_target('cloudflare') == HOST_EDGE;
    assert host_kind_for_target('cli_js') == HOST_CLI_JS;
    assert TARGET_HOST_KIND['react-native'] == HOST_RN;
    assert TARGET_HOST_KIND['cef'] == HOST_WEBVIEW;
}

test "bun-host decision memoizes per project and clears on invalidation" {
    with tempfile.TemporaryDirectory() as tmp {
        toml = Path(tmp) / 'jac.toml';
        toml.write_text(
            '[project]\nname = "host-decision"\n\n'
                + '[plugin.client]\ntarget = "bun"\n'
        );
        (Path(tmp) / 'app.jac').write_text('def:pub ping() -> int { return 1; }\n');
        app_file = str(Path(tmp) / 'app.jac');
        clear_bun_host_decision_cache();
        try {
            assert project_uses_bun_host(app_file) , (
                "target=bun project must resolve to bun host"
            );
            # Decision is cached: a config flip is invisible until invalidated.
            toml.write_text(
                '[project]\nname = "host-decision"\n\n'
                    + '[plugin.client]\ntarget = "web"\n'
            );
            assert project_uses_bun_host(app_file) , (
                "stale cached decision must persist"
            );
            clear_bun_host_decision_cache();
            assert not project_uses_bun_host(app_file) , (
                "after invalidation the flipped target must be honored"
            );
        } finally {
            clear_bun_host_decision_cache();
        }
    }
}

test "native_unmet_capability is table-driven for bare metal" {
    assert native_unmet_capability(HOST_DOM);
    assert not native_unmet_capability(HOST_FFI);
    assert not native_unmet_capability('ENDPOINT');
    assert not native_unmet_capability('SERVER');
}

test "framework_for_host_kind maps bun without a global backend singleton" {
    assert framework_for_host_kind(HOST_BUN) == 'bun';
    assert framework_for_host_kind(HOST_RN) == 'react';
}

test "Host registry exposes target factory aliases" {
    import from jaclang.client.targets.registry {
        get_host_factory,
        get_host_registry,
        get_target_factory,
        get_target_registry
    }
    assert get_target_registry() is get_host_registry();
    assert get_target_factory() is get_host_factory();
    names = get_host_factory().get_available_host_names();
    assert 'bun' in names and 'test' in names;
}

test "bun host row is registered for the P1 stateless tier" {
    import from jaclang.client.targets.registry { get_host_registry }
    host = get_host_registry().get('bun');
    assert host is not None , "bun target must register on the host registry";
    assert str(host.host_kind) == HOST_BUN;
    assert str(host.name) == 'bun';
}

test "hard removal grep script passes for P0 items 1-7" {
    script = Path(JAC_ROOT).parent / 'scripts' / 'check-host-hard-removals.sh';
    assert script.exists() , f"missing hard-removal script at {script}";
    result = subprocess.run(
        ['bash', str(script)],
        cwd=str(Path(JAC_ROOT).parent),
        capture_output=True,
        text=True
    );
    assert result.returncode == 0 , (
        "P0 hard removals 1-7 must stay deleted:\n"
        + (result.stdout or '')
        + (result.stderr or '')
    );
}
