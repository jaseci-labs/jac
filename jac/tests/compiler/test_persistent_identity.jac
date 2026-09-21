"""Persisted graph types resolve locally without sharing app module state."""
import sys;
import from typing { cast }
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { MagicMock }
import from jaclang.compiler.driver.application { prepare_application }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.runtime.prepared { load_prepared_module, forget, application_namespace }
import from jaclang.data.serializer { Serializer }
import from jaclang.data.type_identity { resolution_scope, type_module, TypeResolutionError }
import from jaclang.data.store { AnchorRow, Store }
import from jaclang.server.session { Session }

def exercise(shared: bool) {
    with TemporaryDirectory() as td {
        base = Path(td);
        (base / 'shared').mkdir();
        (base / 'shared' / 'models.jac').write_text(
            'glob values: list[str] = [];\nnode Thing { has v: str = ""; }\n'
        );
        (base / 'jac.toml').write_text(
            '[project]\nname="identity-test"\ndefault-app="writer"\n'
                + '[apps.writer]\nkind="service"\nentry-point="writer"\n'
                + '[apps.reader]\nkind="service"\nentry-point="reader"\n'
                + ('[persistence.domains.records]\nowner="writer"\n'
                    + 'apps=["writer", "reader"]\nmodules=["shared.models"]\n' if shared else '')
        );
        applications: list[any] = [];
        modules: list[any] = [];
        try {
            for name in ['writer', 'reader'] {
                path = base / (name + '.jac');
                path.write_text('import from shared.models { Thing, values }\n');
                app = prepare_application(str(path), JacProgram(), td);
                applications.append(app);
                modules.append(load_prepared_module(app.entry));
            }
            (writer, reader) = modules;
            assert writer.Thing is not reader.Thing;
            writer.values.append('writer');
            assert reader.values == [];
            instance = writer.Thing(v='hello');
            payload: any = Serializer.serialize(instance.__jac__, include_type=True);
            assert '_jac_app_' not in str(payload);
            assert (type_module(writer.Thing) == type_module(reader.Thing)) == shared;
            assert (Serializer.fingerprint(writer.Thing) == Serializer.fingerprint(reader.Thing)) == shared;
            store = MagicMock();
            session = Session(store=cast(Store, store), target_path=applications[1].entry);
            row = AnchorRow(id=instance.__jac__.ensure_id(), kind='NodeAnchor', props=payload);
            got = session._materialize(row);
            store.quarantine.assert_not_called();
            if shared {
                assert got is not None;
                assert isinstance(got.archetype, reader.Thing);
                assert got.archetype.v == 'hello';
                with resolution_scope(applications[0]) {
                    restored: any = Serializer.deserialize(payload);
                    assert isinstance(restored.archetype, writer.Thing);
                }
            } else {
                assert got is None;
                assert session.is_recoverable_quarantine(row.id);
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

test "declared shared types materialize as the consuming app class" { exercise(True); }
test "foreign app-owned types neither quarantine nor heal-prune" { exercise(False); }

test "legacy path-derived names fail explicitly" {
    try {
        Serializer._get_class('_jac_app_0123456789abcdef.shared.models', 'Thing');
        assert False;
    } except TypeResolutionError as error {
        assert 'migrate' in str(error);
    }
}
