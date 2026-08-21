"""P1 acceptance tests for jaseci-labs/jac#8144 (BunHost stateless tier).

Derived from PLAN.md Priority 1 only — not from implementation internals.
"""

import os;
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support { JAC_ROOT }
import from jaclang.jac0core.host { HOST_BUN, HOST_CPYTHON }
import from jaclang.jac0core.sv_service_host {
    bun_service_artifact_path,
    is_bun_sv_service,
    resolve_sv_service_host,
    sv_host_env_key
}
import from jaclang.runtimelib.bun_service_builder { build_bun_service_artifact }


glob _STATELESS_SVC: str = 'def:pub ping() -> int {\n' '    return 42;\n' '}\n',
     _ROOT_SVC: str = (
         'walker:pub touch_root {\n'
         '    can run with Root entry {\n'
         '        report True;\n'
         '    }\n'
         '}\n'
     ),
     _CLIENT_DIR: Path = Path(JAC_ROOT) / 'jaclang' / 'runtimelib' / 'client';


def _write_service(tmp: str, name: str, source: str) -> str {
    path = os.path.join(tmp, f"{name}.jac");
    with open(path, 'w') as f {
        f.write(source);
    }
    return path;
}


test "resolve_sv_service_host defaults to cpython without a bun artifact" {
    with tempfile.TemporaryDirectory() as tmp {
        assert resolve_sv_service_host('demo', tmp) == HOST_CPYTHON;
        assert not is_bun_sv_service('demo', tmp);
    }
}

test "resolve_sv_service_host selects bun when artifact exists" {
    with tempfile.TemporaryDirectory() as tmp {
        artifact = bun_service_artifact_path('demo', tmp);
        artifact.parent.mkdir(parents=True, exist_ok=True);
        artifact.write_text('export default {};\n', encoding='utf-8');
        assert resolve_sv_service_host('demo', tmp) == HOST_BUN;
        assert is_bun_sv_service('demo', tmp);
    }
}

test "build_bun_service_artifact emits Bun.serve entry with functions health route" {
    with tempfile.TemporaryDirectory() as tmp {
        _write_service(tmp, 'stateless', _STATELESS_SVC);
        artifact = build_bun_service_artifact('stateless', tmp);
        assert artifact.exists();
        text = artifact.read_text(encoding='utf-8');
        assert 'Bun.serve' in text , "P1 entry must bootstrap with Bun.serve";
        assert '/functions' in text , "P1 runtime must expose the /functions health route";
    }
}

test "build_bun_service_artifact accepts root-touching modules with BunStore (P2)" {
    with tempfile.TemporaryDirectory() as tmp {
        _write_service(tmp, 'rooty', _ROOT_SVC);
        artifact = build_bun_service_artifact('rooty', tmp);
        assert artifact.exists();
        text = artifact.read_text(encoding='utf-8');
        assert 'Bun.serve' in text;
    }
}

test "ServerNpmProvider is wired for jac install --npm --server" {
    plugin = (_CLIENT_DIR / 'plugin_config.jac').read_text(encoding='utf-8');
    provider = (_CLIENT_DIR / 'server_npm_provider.jac').read_text(encoding='utf-8');
    assert 'ServerNpmProvider' in plugin;
    assert 'register_ecosystem_providers' in plugin;
    assert 'cli_flag: str = "--server"' in provider;
    assert 'server_npm_root' in provider;
    assert ".jac' / 'server'" in provider or '.jac/server' in provider;
}

test "test host registers on the host registry" {
    register = (_CLIENT_DIR / 'targets' / 'register.jac').read_text(encoding='utf-8');
    target = (_CLIENT_DIR / 'targets' / 'test_host_target.jac').read_text(
        encoding='utf-8'
    );
    assert 'TestHost' in register;
    assert 'registry.register(TestHost())' in register;
    assert 'host_kind: str = HOST_CPYTHON' in target;
    assert 'name: str = "test"' in target;
}

test "sv_client uses test host env override instead of _test_clients dispatch" {
    sv_client = (Path(JAC_ROOT) / 'jaclang' / 'runtimelib' / 'sv_client.jac').read_text(
        encoding='utf-8'
    );
    assert 'sv_host_env_key' in sv_client;
    assert "os.environ[sv_host_env_key(module_name)] = 'test'" in sv_client;
    assert 'register_test_adapter' in sv_client;
    assert 'glob _test_clients' not in sv_client;
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
