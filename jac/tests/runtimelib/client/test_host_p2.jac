"""P2 acceptance tests for jaseci-labs/jac#8144 (BunStore + root-touching services).

Derived from PLAN.md Priority 2 only — not from implementation internals.
"""

import os;
import tempfile;
import from pathlib { Path }
import from tests.support { JAC_ROOT }
import from jaclang.jac0core.host { HOST_BUN }
import from jaclang.jac0core.sv_service_host {
    bun_service_artifact_path,
    resolve_sv_service_host
}
import from jaclang.runtimelib.bun_service_builder { build_bun_service_artifact }
import from jaclang.runtimelib.store { SCHEMA_VERSION }


glob _STATELESS_SVC: str = 'def:pub ping() -> int {\n' '    return 42;\n' '}\n',
     _ROOT_SVC: str = (
         'node Doc {\n'
         '    has label: str = "";\n'
         '}\n'
         'def:pub save_doc(label: str) -> None {\n'
         '    root ++> Doc(label=label);\n'
         '}\n'
         'walker:pub touch_root {\n'
         '    can run with Root entry {\n'
         '        report True;\n'
         '    }\n'
         '}\n'
     ),
     _PERSIST_SCHEMA_TABLES: tuple = (
         'anchors',
         'graph_types',
         'kv_state',
         'quarantine'
     ),
     _RUNTIMELIB: Path = Path(JAC_ROOT) / 'jaclang' / 'runtimelib',
     _BUILDER: Path = _RUNTIMELIB / 'bun_service_builder.jac';


def _write_service(tmp: str, name: str, source: str) -> str {
    path = os.path.join(tmp, f"{name}.jac");
    with open(path, 'w') as f {
        f.write(source);
    }
    return path;
}


test "BunStore module implements Store over Bun.sql" {
    bun_store = _RUNTIMELIB / 'bun_store.jac';
    bun_impl = _RUNTIMELIB / 'impl' / 'bun_store.impl.jac';
    assert bun_store.exists() , f"missing BunStore declaration at {bun_store}";
    assert bun_impl.exists() , f"missing BunStore implementation at {bun_impl}";
    combined = bun_store.read_text(encoding='utf-8')
        + bun_impl.read_text(encoding='utf-8');
    assert 'Bun.sql' in combined , "P2 store must use Bun.sql against Postgres";
    assert 'obj BunStore' in combined or 'class BunStore' in combined;
}


test "BunStore shares the PgStore anchor schema and version stamp" {
    pg_impl = _RUNTIMELIB / 'impl' / 'store.impl.jac';
    bun_impl = _RUNTIMELIB / 'impl' / 'bun_store.impl.jac';
    assert bun_impl.exists();
    pg_text = pg_impl.read_text(encoding='utf-8');
    bun_text = bun_impl.read_text(encoding='utf-8');
    for table in _PERSIST_SCHEMA_TABLES {
        assert f"CREATE TABLE IF NOT EXISTS {table}" in pg_text;
        assert table in bun_text , (
            f"BunStore must target the same Postgres schema table {table!r}"
        );
    }
    assert str(SCHEMA_VERSION) in bun_text , (
        "BunStore must stamp rows with the shared SCHEMA_VERSION"
    );
}


test "server_runtime wires BunStore into walker spawn context" {
    runtime_jac = _RUNTIMELIB / 'server_runtime.jac';
    runtime_js = _RUNTIMELIB / 'server_runtime.js';
    text = runtime_jac.read_text(encoding='utf-8');
    if runtime_js.exists() {
        text += runtime_js.read_text(encoding='utf-8');
    }
    assert 'BunStore' in text or '__jacInitBunStore' in text , (
        "server runtime must bootstrap a Bun-backed Store for walkers"
    );
    assert '__jacServerSpawnWalker' in text;
    assert 'Bun.sql' in text or 'bun_store' in text.lower();
}


test "build_bun_service_artifact accepts root-touching modules in P2" {
    with tempfile.TemporaryDirectory() as tmp {
        _write_service(tmp, 'persisted', _ROOT_SVC);
        artifact = build_bun_service_artifact('persisted', tmp);
        assert artifact.exists();
        text = artifact.read_text(encoding='utf-8');
        assert 'Bun.serve' in text;
        assert '/walkers' in text or '/walker/' in text;
    }
}


test "P1 stateless root gate is removed once BunStore is available" {
    builder = _BUILDER.read_text(encoding='utf-8');
    assert 'wait for P2 PERSIST on bun' not in builder , (
        "P2 must replace the P1 hard reject with Store-backed hosting"
    );
    assert 'module_has_root_access' not in builder or 'BunStore' in builder , (
        "root-touching modules should gate on Store availability, not a blanket reject"
    );
}


test "root-touching bun artifact still resolves through sv_service_host" {
    with tempfile.TemporaryDirectory() as tmp {
        _write_service(tmp, 'persisted', _ROOT_SVC);
        artifact = build_bun_service_artifact('persisted', tmp);
        assert artifact == bun_service_artifact_path('persisted', tmp);
        assert resolve_sv_service_host('persisted', tmp) == HOST_BUN;
    }
}


test "stateless bun services keep working after P2 store wiring" {
    with tempfile.TemporaryDirectory() as tmp {
        _write_service(tmp, 'stateless', _STATELESS_SVC);
        artifact = build_bun_service_artifact('stateless', tmp);
        text = artifact.read_text(encoding='utf-8');
        assert 'Bun.serve' in text;
        assert '/functions' in text;
        assert resolve_sv_service_host('stateless', tmp) == HOST_BUN;
    }
}


test "scale microservices config can pin a persist service to bun host" {
    import from jaclang.scale.config.config_loader {
        get_scale_config,
        reset_scale_config
    }
    with tempfile.TemporaryDirectory() as tmp {
        _write_service(tmp, 'persisted', _ROOT_SVC);
        toml = os.path.join(tmp, 'jac.toml');
        with open(toml, 'w') as f {
            f.write(
                '[project]\n'
                    + 'name = "persist-demo"\n'
                    + 'entry-point = "persisted.jac"\n\n'
                    + '[scale.microservices.services.persisted]\n'
                    + 'host = "bun"\n'
            );
        }
        old_cwd = os.getcwd();
        try {
            os.chdir(tmp);
            reset_scale_config();
            cfg = get_scale_config(Path(tmp));
            svc_cfg = cfg.get_microservices_config().get('services', {}).get(
                'persisted', {}
            );
            assert str(svc_cfg.get('host', '')).lower() == 'bun';
            assert resolve_sv_service_host('persisted', tmp) == HOST_BUN;
        } finally {
            os.chdir(old_cwd);
            reset_scale_config();
        }
    }
}
