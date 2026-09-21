"""Persisted graph types resolve locally without sharing app module state."""
import sys;
import from typing { cast }
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { MagicMock }
import from jaclang.compiler.driver.application { prepare_application }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.runtime.prepared {
    load_prepared_module,
    forget,
    application_namespace,
    PreparedApplication
}
import from jaclang.data.serializer { Serializer }
import from jaclang.data.type_identity {
    resolution_scope,
    type_module,
    TypeResolutionError,
    UnavailableType
}
import from jaclang.data.store { AnchorRow, Store }
import from jaclang.server.session { Session }

def exercise(shared: bool, evolve: bool = False) {
    with TemporaryDirectory() as td, TemporaryDirectory() as storage {
        base = Path(td);
        (base / 'shared').mkdir();
        (base / 'shared' / 'models.jac').write_text(
            'glob values: list[str] = [];\nnode Thing { has v: str = ""; }\n'
        );
        (base / 'jac.toml').write_text(
            '[project]\nname="identity-test"\ndefault-app="writer"\n'
                + '[apps.writer]\nkind="service"\nentry-point="writer"\n'
                + '[apps.reader]\nkind="service"\nentry-point="reader"\n'
        );
        applications: list[PreparedApplication] = [];
        modules: list[any] = [];
        try {
            for name in ['writer', 'reader'] {
                if not shared and name == 'reader' {
                    manifest = base / 'jac.toml';
                    manifest.write_text(
                        manifest.read_text().replace(
                            'identity-test', 'other-application'
                        )
                    );
                }
                path = base / (name + '.jac');
                path.write_text('import from shared.models { Thing, values }\n');
                app = prepare_application(str(path), JacProgram(), td);
                applications.append(app);
                modules.append(load_prepared_module(app.entry));
                if evolve and name == 'writer' {
                    (base / 'shared' / 'models.jac').write_text(
                        'glob values: list[str] = [];\nnode Thing { has v: str = "", generation: int = 2; }\n'
                    );
                }
            }
            (writer, reader) = modules;
            assert writer.Thing is not reader.Thing;
            writer.values.append('writer');
            assert reader.values == [];
            instance = writer.Thing(v='hello');
            payload: any = Serializer.serialize(instance.__jac__, include_type=True);
            assert '_jac_app_' not in str(payload);
            assert (type_module(writer.Thing) == type_module(reader.Thing)) == shared;
            assert (
                Serializer.fingerprint(writer.Thing)
                == Serializer.fingerprint(reader.Thing)
            )
                == (shared and not evolve);
            store = MagicMock();
            session = Session(
                store=cast(Store, store), target_path=applications[1].entry
            );
            row = AnchorRow(
                id=instance.__jac__.ensure_id(), kind='NodeAnchor', props=payload
            );
            got = session._materialize(row);
            store.quarantine.assert_not_called();
            with resolution_scope(applications[1]) {
                try {
                    Serializer._get_class(
                        type_module(reader.Thing).replace(
                            'shared.models', 'removed.models'
                        ),
                        'Thing'
                    );
                    assert False , 'a missing local schema was mistaken for foreign data';
                } except UnavailableType {}
            }

            # Both application sessions use the same physical store, but each
            # must hydrate its own class, including SQL type-filtered reads.
            import from jaclang.server.session { runtime_for_base }
            import from jaclang.data.store { PgStore }
            import from jaclang.runtime.archetype { Root, EdgeAnchor, GenericEdge }
            import from jaclang.runtime.graph_query { GraphQuery, QHop }
            import from jaclang.data.query_planner { resolve_query }
            runtime = runtime_for_base(storage, applications[0].entry).runtime;
            connection = runtime.ensure();
            writing = Session(
                store=PgStore(conninfo=connection, auto_schema=True),
                target_path=applications[0].entry
            );
            import from uuid { UUID }
            root_anchor = Root().__jac__;
            root_anchor.id = UUID("00000000-0000-0000-0000-000000000000");
            root_anchor.persistent = True;
            instance.__jac__.persistent = True;
            edge_anchor = EdgeAnchor(
                archetype=cast(any, GenericEdge()),
                source=root_anchor,
                target=instance.__jac__,
                is_undirected=False
            );
            edge_anchor.persistent = True;
            root_anchor.edges.append(edge_anchor);
            instance.__jac__.edges.append(edge_anchor);
            for anchor in [root_anchor, instance.__jac__, edge_anchor] {
                writing.put(anchor);
            }
            root_id = root_anchor.ensure_id();
            writing.commit();
            import asyncio;
            import from jaclang.runtime.context { ExecutionContext }
            parent = ExecutionContext(
                base_path_dir='', full_target_path=applications[0].entry
            );
            parent.base_path_dir = storage;
            parent.mem = writing;
            provider = asyncio.run(
                ExecutionContext.for_target(reader.Thing, parent, str(root_id))
            );
            reading = cast(Session, provider.mem);
            reader_store = cast(PgStore, reading.store);
            assert reading is not writing;
            assert reader_store.conninfo.database == connection.database;
            assert provider.user_root.ensure_id() == root_id;
            try {
                loaded_root: any = reading.get(root_id);
                assert loaded_root is not None;
                found = resolve_query(
                    reading,
                    GraphQuery(
                        loaded_root.archetype, hops=[QHop(dir=2, nd=reader.Thing)]
                    )
                );
                assert len(found) == (1 if shared else 0);
                if shared {
                    assert isinstance(found[0].archetype, reader.Thing);
                    assert found[0].archetype.v == 'hello';
                } else {
                    assert reading.get(instance.__jac__.ensure_id()) is None;
                    assert reading.preserve_unresolved_ref(
                        instance.__jac__.ensure_id()
                    );
                    assert resolve_query(
                        reading, GraphQuery(loaded_root.archetype, hops=[QHop(dir=2)])
                    )
                        == [];
                    reading.commit();
                    assert reader_store.rows(
                        "SELECT count(*) FROM anchors WHERE kind = 'EdgeAnchor'", {}
                    )[0][0]
                        == 1;
                    assert reader_store.rows(
                        "SELECT count(*) FROM anchors WHERE kind = 'NodeAnchor'", {}
                    )[0][0]
                        == 2;
                }
                assert reader_store.rows('SELECT count(*) FROM quarantine', {})[0][0]
                    == 0;
            } finally {
                provider.close();
                writing.close();
            }

            if shared {
                assert got is not None;
                assert isinstance(got.archetype, reader.Thing);
                assert got.archetype.v == 'hello';
                if evolve {
                    assert got.archetype.generation == 2;
                }
                legacy = writer.Thing.__module__ + '.Thing';
                Serializer.register_alias(legacy, reader.Thing);
                try {
                    with resolution_scope(applications[1]) {
                        assert Serializer._get_class(writer.Thing.__module__, 'Thing')
                            is reader.Thing;
                    }
                } finally {
                    Serializer._aliases.pop(legacy, None);
                }
                with resolution_scope(applications[0]) {
                    restored: any = Serializer.deserialize(payload);
                    assert isinstance(restored.archetype, writer.Thing);
                }
            } else {
                assert got is None;
                assert session.preserve_unresolved_ref(row.id);
            }
        } finally {
            for app in applications {
                forget(app.entry);
                prefix = application_namespace(app);
                for name in list(sys.modules) {
                    if name == prefix or name.startswith(prefix + '.') {
                        sys.modules.pop(name, None);
                    }
                }
            }
        }
    }
}

test "services automatically share stored types and the application database" {
    exercise(True);
}

test "unrelated application types neither quarantine nor heal-prune" {
    exercise(False);
}

test "legacy path-derived names fail explicitly" {
    try {
        Serializer._get_class('_jac_app_0123456789abcdef.shared.models', 'Thing');
        assert False;
    } except TypeResolutionError as error {
        assert 'migrate' in str(error);
    }
}


test "shared schema additions retain stored values and apply defaults" {
    exercise(True, True);
}

test "missing local schema fails without quarantine" {
    import from uuid { uuid4 }
    store = MagicMock();
    session = Session(store=cast(Store, store));
    row = AnchorRow(
        id=uuid4(),
        kind='NodeAnchor',
        props={
            '__type__': 'NodeAnchor',
            '__module__': 'jaclang.runtime.archetype',
            'id': str(uuid4()),
            'archetype': {'__type__': 'Missing', '__module__': 'unavailable.schema'}
        }
    );
    try {
        session._materialize(row);
        assert False , 'missing schema was silently treated as missing data';
    } except TypeResolutionError {}
    store.quarantine.assert_not_called();
}

test "durable identity survives a different app process and checkout location" {
    import subprocess;
    import from tests.support { compiler_python_command }
    with TemporaryDirectory() as td {
        base = Path(td);
        for directory in ['build-machine', 'deployment'] {
            project = base / directory;
            (project / 'shared').mkdir(parents=True);
            (project / 'jac.toml').write_text(
                '[project]\nname="portable"\ndefault-app="writer"\n'
                    + '[apps.writer]\nkind="service"\nentry-point="writer"\n'
                    + '[apps.reader]\nkind="service"\nentry-point="reader"\n'
            );
            (project / 'shared' / 'models.jac').write_text(
                'node Thing { has v: str = ""; }'
            );
            for name in ['writer', 'reader'] {
                (project / (name + '.jac')).write_text(
                    'import from shared.models { Thing }'
                );
            }
        }
        script = "import json, sys\n"
            + "from pathlib import Path\n"
            + "from jaclang.compiler.driver.application import prepare_application\n"
            + "from jaclang.compiler.driver.program import JacProgram\n"
            + "from jaclang.runtime.prepared import load_prepared_module\n"
            + "from jaclang.data.serializer import Serializer\n"
            + "from jaclang.data.type_identity import resolution_scope\n"
            + "root, app, path = sys.argv[1:]\n"
            + "prepared = prepare_application(str(Path(root)/(app+'.jac')), JacProgram(), root)\n"
            + "module = load_prepared_module(prepared.entry)\n"
            + "with resolution_scope(prepared):\n"
            + " if app == 'writer':\n"
            + "  item = module.Thing(v='persisted')\n"
            + "  Path(path).write_text(json.dumps([Serializer.serialize(item.__jac__, include_type=True), Serializer.fingerprint(module.Thing)]))\n"
            + " else:\n"
            + "  payload, fingerprint = json.loads(Path(path).read_text())\n"
            + "  restored = Serializer.deserialize(payload)\n"
            + "  assert isinstance(restored.archetype, module.Thing)\n"
            + "  assert restored.archetype.v == 'persisted'\n"
            + "  assert Serializer.fingerprint(module.Thing) == fingerprint\n"
            + "print('IDENTITY_OK')\n";
        for (directory, app) in [
            ('build-machine', 'writer'),
            ('deployment', 'reader')
        ] {
            result = subprocess.run(
                compiler_python_command(
                    script, str(base / directory), app, str(base / 'row.json')
                ),
                capture_output=True,
                text=True,
                timeout=180
            );
            assert result.returncode == 0 , result.stdout + result.stderr;
            assert 'IDENTITY_OK' in result.stdout;
        }
    }
}


test "repeated main execution keeps prior module globals and type identities" {
    previous = sys.modules.get('__main__');
    with TemporaryDirectory() as td {
        applications: list[PreparedApplication] = [];
        modules: list[any] = [];
        try {
            for name in ['first', 'second'] {
                path = Path(td) / (name + '.jac');
                path.write_text(
                    f'glob marker: str = "{name}";\n'
                        + 'node Record { has value: str = "saved"; }\n'
                        + 'def read_marker -> str { return marker; }\n'
                );
                app = prepare_application(str(path), JacProgram(), td);
                applications.append(app);
                modules.append(load_prepared_module(app.entry, app, as_main=True));
            }
            (first, second) = modules;
            assert first is not second;
            assert first.read_marker() == 'first';
            assert second.read_marker() == 'second';
            assert type_module(first.Record) != type_module(second.Record);
            payload = Serializer.serialize(first.Record(), include_type=True);
            with resolution_scope(applications[0]) {
                restored = Serializer.deserialize(cast(dict[str, object], payload));
                assert type(restored) is first.Record;
            }
        } finally {
            for app in applications {
                forget(app.entry);
            }
            if previous is not None {
                sys.modules['__main__'] = previous;
            }
        }
    }
}
