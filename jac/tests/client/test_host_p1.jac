"""P1 acceptance tests for jaseci-labs/jac#8144 (BunHost stateless tier).

Derived from PLAN.md Priority 1 only — not from implementation internals.
"""

import os;
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support { JAC_ROOT, write_service }
import from jaclang.jac0core.host { HOST_BUN, HOST_CPYTHON, HOST_TEST }
import from jaclang.jac0core.sv_service_host {
    bun_artifact_stamp_path,
    bun_service_artifact_path,
    bun_service_inputs_digest,
    is_bun_sv_service,
    resolve_sv_service_host
}
import from jaclang.server.sv_client { sv_host_env_key }
import from jaclang.bun_service_builder { build_bun_service_artifact }


glob _STATELESS_SVC: str = 'def:pub ping() -> int {\n' '    return 42;\n' '}\n',
     _ROOT_SVC: str = (
         'walker:pub touch_root {\n'
         '    can run with Root entry {\n'
         '        report True;\n'
         '    }\n'
         '}\n'
     ),
     _CLIENT_DIR: Path = Path(JAC_ROOT) / 'jaclang' / 'client';


test "resolve_sv_service_host defaults to cpython without a bun artifact" {
    with tempfile.TemporaryDirectory() as tmp {
        assert resolve_sv_service_host('demo', tmp) == HOST_CPYTHON;
        assert not is_bun_sv_service('demo', tmp);
    }
}

test "resolve_sv_service_host selects bun when a fresh artifact exists" {
    with tempfile.TemporaryDirectory() as tmp {
        write_service(tmp, 'demo', _STATELESS_SVC);
        artifact = bun_service_artifact_path('demo', tmp);
        artifact.parent.mkdir(parents=True, exist_ok=True);
        artifact.write_text('export default {};\n', encoding='utf-8');
        assert resolve_sv_service_host('demo', tmp) == HOST_CPYTHON , (
            "stamp-less artifact must not select the bun host (stale)"
        );
        stamp = bun_artifact_stamp_path('demo', tmp);
        stamp.write_text(bun_service_inputs_digest('demo', tmp), encoding='utf-8');
        assert resolve_sv_service_host('demo', tmp) == HOST_BUN;
        assert is_bun_sv_service('demo', tmp);
    }
}

test "edited service source invalidates a previously fresh artifact" {
    with tempfile.TemporaryDirectory() as tmp {
        write_service(tmp, 'demo', _STATELESS_SVC);
        artifact = bun_service_artifact_path('demo', tmp);
        artifact.parent.mkdir(parents=True, exist_ok=True);
        artifact.write_text('export default {};\n', encoding='utf-8');
        stamp = bun_artifact_stamp_path('demo', tmp);
        stamp.write_text(bun_service_inputs_digest('demo', tmp), encoding='utf-8');
        assert resolve_sv_service_host('demo', tmp) == HOST_BUN;
        write_service(tmp, 'demo', 'def:pub ping() -> int {\n    return 7;\n}\n');
        assert resolve_sv_service_host('demo', tmp) == HOST_CPYTHON , (
            "source edits must invalidate the artifact (edits self-invalidate)"
        );
    }
}

test "build_bun_service_artifact emits Bun.serve entry with functions health route" {
    with tempfile.TemporaryDirectory() as tmp {
        write_service(tmp, 'stateless', _STATELESS_SVC);
        artifact = build_bun_service_artifact('stateless', tmp);
        assert artifact.exists();
        text = artifact.read_text(encoding='utf-8');
        assert '.serve({' in text , "P1 entry must bootstrap with Bun.serve";
        assert '/functions' in text , "P1 runtime must expose the /functions health route";
    }
}

test "build_bun_service_artifact accepts root-touching modules with BunStore (P2)" {
    with tempfile.TemporaryDirectory() as tmp {
        write_service(tmp, 'rooty', _ROOT_SVC);
        artifact = build_bun_service_artifact('rooty', tmp);
        assert artifact.exists();
        text = artifact.read_text(encoding='utf-8');
        assert '.serve({' in text;
    }
}

test "ServerNpmProvider is wired for jac install --npm --server" {
    import from jaclang.client.server_npm_provider {
        ServerNpmProvider,
        server_npm_root
    }
    provider = ServerNpmProvider();
    assert str(provider.cli_flag) == '--server';
    assert str(server_npm_root(Path('.'))).endswith('.jac/server');
    plugin = (_CLIENT_DIR / 'plugin_config.jac').read_text(encoding='utf-8');
    assert 'register_ecosystem_providers' in plugin;
}

test "test host registers on the host registry" {
    import from jaclang.client.targets.registry { get_host_registry }
    host = get_host_registry().get('test');
    assert host is not None , "test target must register on the host registry";
    assert str(host.host_kind) == HOST_TEST;
    assert str(host.name) == 'test';
}

test "sv_client registers and clears test-host env overrides" {
    import from jaclang.server { sv_client }
    env_key = sv_host_env_key('env_probe_mod');
    os.environ.pop(env_key, None);
    try {
        sv_client.register_test_client('env_probe_mod');
        assert os.environ.get(env_key) == 'test';
    } finally {
        sv_client.clear_test_clients();
    }
    assert env_key not in os.environ , (
        "clear_test_clients must unset registered JAC_SV_*_HOST keys"
    );
}

test "hard removal grep script passes for P1 items 8-10" {
    script = Path(JAC_ROOT).parent / 'scripts' / 'check-host-hard-removals.sh';
    result = subprocess.run(
        ['bash', str(script)],
        cwd=str(Path(JAC_ROOT).parent),
        capture_output=True,
        text=True
    );
    combined = (result.stdout or '') + (result.stderr or '');
    assert result.returncode == 0 , (
        "P1 hard removals 8-10 must stay deleted:\n" + combined
    );
    assert 'Hard-removal grep check passed' in combined;
}
