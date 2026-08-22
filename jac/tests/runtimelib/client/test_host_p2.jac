"""P2 acceptance tests for jaseci-labs/jac#8144 (BunStore + root-touching services).

Derived from PLAN.md Priority 2 only — not from implementation internals.
"""

import os;
import tempfile;
import from pathlib { Path }
import from tests.support { JAC_ROOT, write_service, resolved_bun }
import from jaclang.jac0core.host { HOST_BUN }
import from jaclang.jac0core.sv_service_host {
    bun_service_artifact_path,
    resolve_sv_service_host
}
import from jaclang.runtimelib.bun_service_builder { build_bun_service_artifact }


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


test "BunStore implements the Store contract in JS over Bun.sql" {
    # The Jac-side bun_store.jac is a documentation pointer only; the real
    # implementation is the JS adapter bundled into service artifacts.
    bun_store_js = _RUNTIMELIB / 'bun_store.js';
    assert bun_store_js.exists();
    js_text = bun_store_js.read_text(encoding='utf-8');
    assert 'class BunStore' in js_text , (
        "BunStore must be implemented by the bundled JS adapter"
    );
    assert 'Bun.sql' in js_text or 'from "bun"' in js_text , (
        "P2 store must use Bun.sql against Postgres"
    );
    assert 'SCHEMA_STAMP_KEY' in js_text and 'SHOW server_version_num' in js_text , (
        "BunStore must compute the PgStore-compatible schema fingerprint"
    );
}


test "BunStore shares the PgStore anchor schema and version stamp" {
    import from jaclang.runtimelib.store { SCHEMA_SQL }
    pg_ddl = '\n'.join(str(stmt) for stmt in SCHEMA_SQL);
    bun_schema = _RUNTIMELIB / 'bun_store.js';
    assert bun_schema.exists();
    bun_text = bun_schema.read_text(encoding='utf-8');
    for table in _PERSIST_SCHEMA_TABLES {
        assert f"CREATE TABLE IF NOT EXISTS {table}" in pg_ddl , (
            f"shared SCHEMA_SQL must create Postgres table {table!r}"
        );
    }
    assert 'SCHEMA_SQL' in bun_text , (
        "BunStore must consume the shared exported SCHEMA_SQL constant"
    );
}


test "BunStore fingerprint matches the PgStore formula byte for byte" {
    # Drift pin: run computeSchemaFingerprint under real bun and compare with
    # the Python formula (PgStore._schema_fingerprint) over identical inputs.
    import subprocess;
    import tempfile;
    import hashlib;
    import json;
    import from pathlib { Path }
    import from jaclang.runtimelib.store { SCHEMA_SQL, SCHEMA_VERSION }
    import from tests.support { bun_runtime_available }

    if not bun_runtime_available() {
        print('[skip] bun runtime unavailable');
        return;
    }

    promotions = {'arch_a': ['field1', 'field2'], 'b': ['x']};
    stmts = [str(stmt) for stmt in SCHEMA_SQL];
    server_major = 17;

    h = hashlib.sha256();
    h.update(str(SCHEMA_VERSION).encode());
    h.update(str(server_major).encode());
    for stmt in stmts {
        h.update(stmt.encode());
    }
    for arch in sorted(promotions.keys()) {
        for fld in promotions[arch] {
            col = f"g_{arch}_{fld}";
            h.update(f"('{arch}', '{fld}', '{col}')".encode());
        }
    }
    expected = f"{SCHEMA_VERSION}:{h.hexdigest()[:24]}";

    with tempfile.TemporaryDirectory(dir=None) as tmp {
        tmp_path = Path(tmp);
        (tmp_path / 'bun_store.js').write_bytes(
            (_RUNTIMELIB / 'bun_store.js').read_bytes()
        );
        stub = (
            'export const SCHEMA_SQL = '
                + json.dumps(stmts) + ';\n'
            + f'export const SCHEMA_VERSION = {int(SCHEMA_VERSION)};\n'
            + 'export const PROMOTIONS = {};\n'
        );
        (tmp_path / 'bun_schema.js').write_text(stub, encoding='utf-8');
        store_js = str(tmp_path / 'bun_store.js');
        schema_js = str(tmp_path / 'bun_schema.js');
        script = (
            'import { computeSchemaFingerprint } from "' + store_js + '";\n'
            'import { SCHEMA_SQL, SCHEMA_VERSION } from "' + schema_js + '";\n'
            'const promos = '
                + json.dumps(promotions) + ';\n'
            'console.log(computeSchemaFingerprint('
            'SCHEMA_VERSION, 17, SCHEMA_SQL, promos));'
        );
        proc = subprocess.run(
            [str(resolved_bun() or 'bun'), '-e', script],
            capture_output=True,
            text=True,
            timeout=60
        );
        assert proc.returncode == 0 , f"bun failed: {proc.stderr}";
        got = proc.stdout.strip().splitlines()[-1].strip();
        assert got == expected , f"fingerprint drift: js={got} py={expected}";
    }
}


test "server_runtime wires BunStore into walker spawn context" {
    runtime_jac = _RUNTIMELIB / 'server_runtime.jac';
    text = runtime_jac.read_text(encoding='utf-8');
    assert 'BunStore' in text or '__jacInitBunStore' in text , (
        "server runtime must bootstrap a Bun-backed Store for walkers"
    );
    assert '__jacServerSpawnWalker' in text;
    assert 'Bun.sql' in text or 'bun_store' in text.lower();
}


test "build_bun_service_artifact accepts root-touching modules in P2" {
    with tempfile.TemporaryDirectory() as tmp {
        write_service(tmp, 'persisted', _ROOT_SVC);
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
        write_service(tmp, 'persisted', _ROOT_SVC);
        artifact = build_bun_service_artifact('persisted', tmp);
        assert artifact == bun_service_artifact_path('persisted', tmp);
        assert resolve_sv_service_host('persisted', tmp) == HOST_BUN;
    }
}


test "stateless bun services keep working after P2 store wiring" {
    with tempfile.TemporaryDirectory() as tmp {
        write_service(tmp, 'stateless', _STATELESS_SVC);
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
        write_service(tmp, 'persisted', _ROOT_SVC);
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
