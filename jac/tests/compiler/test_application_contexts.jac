"""Colocated apps load distinct copies of shared Jac modules from prepared code."""
import builtins;
import sys;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from types { SimpleNamespace }
import from unittest.mock { patch }
import from jaclang.runtime.prepared {
    PreparedApplication,
    publish,
    clear,
    load_prepared_module,
    application_namespace
}
import from jaclang.runtime.runtime { JacRuntime as Jac }

test "sealed service contracts use the target module app identity" {
    import json;
    import from jaclang.server.endpoint_contract { check_endpoint_contract }
    with TemporaryDirectory() as td {
        entry_path = str(Path(td) / 'main.jac');
        service = str(Path(td) / 'service.jac');
        app = PreparedApplication(td, entry_path);
        app.manifests = {entry_path: {'app': 'web'}, service: {'app': 'service'}};
        module_name = 'prepared_service_contract_fixture';
        target = SimpleNamespace(__module__=module_name);
        module = SimpleNamespace(__file__=service);
        publish(app);
        try {
            with patch.dict(sys.modules, {module_name: module}) {
                for (identity, expected) in [('service', True), ('web', False)] {
                    request = SimpleNamespace(
                        headers={
                            'X-Jac-Endpoint': json.dumps(
                                [identity, 'service.jac', 'walker', 'Ping']
                            )
                        }
                    );
                    mismatch = check_endpoint_contract(
                        request, target, 'walker', 'Ping', 'web'
                    );
                    assert (mismatch is None) == expected;
                    if mismatch is not None {
                        assert mismatch.error.code == 'ENDPOINT_CONTRACT_MISMATCH';
                    }
                }
            }
        } finally {
            clear();
        }
    }
}

test "a sealed entry loads without a package initializer" {
    import jaclang.jac0core.sealed as sealed;
    with TemporaryDirectory() as td {
        path = str(Path(td) / 'main.jac');
        Path(path).write_text('');
        helper_path = str(Path(td) / 'helper.jac');
        Path(helper_path).write_text('');
        app = PreparedApplication(td, path);
        app.code[path] = builtins.compile('values = []', path, 'exec');
        app.code[helper_path] = builtins.compile(
            'from .main import values', helper_path, 'exec'
        );
        name = 'prepared_namespace_fixture';
        info = {'module': name + '.main'};
        image = SimpleNamespace(
            package=name,
            manifest={
                'modules': {
                    'main.jac': info,
                    'helper.jac': {'module': name + '.helper'}
                }
            },
            index={
                name + '.main': (info, 'main.jac'),
                name + '.helper': ({'module': name + '.helper'}, 'helper.jac')
            }
        );
        publish(app);
        try {
            with patch.object(sealed, 'image_for_bundle_dir', return_value=image) {
                loaded: any = load_prepared_module(path);
                assert loaded.__name__ == name + '.main';
                helper: any = load_prepared_module(helper_path);
                assert helper.__name__ == name + '.helper';
                assert helper.values is loaded.values;
            }
        } finally {
            clear();
            sys.modules.pop(name + '.main', None);
            sys.modules.pop(name + '.helper', None);
            sys.modules.pop(name, None);
        }
    }
}

test "prepared app imports cannot share mutable module state" {
    with TemporaryDirectory() as td {
        base = Path(td);
        helper = str(base / 'helper.jac');
        (base / 'helper.jac').write_text('');
        applications = [];
        names = [];
        try {
            for name in ['a', 'b'] {
                path = str(base / (name + '.jac'));
                Path(path).write_text('');
                app = PreparedApplication(td, path);
                app.code[path] = builtins.compile(
                    ('from . import b\n' if name == 'a' else '')
                        + 'from helper import values\nvalues.append(__name__)\n',
                    path,
                    'exec'
                );
                app.code[helper] = builtins.compile('values = []\n', helper, 'exec');
                initializer = str(base / '__init__.jac');
                Path(initializer).write_text('');
                app.code[initializer] = builtins.compile(
                    'initialized = True\n', initializer, 'exec'
                );
                applications.append(app);
                names.append(application_namespace(app));
            }
            applications[0].applications = [applications[1]];
            publish(applications[0]);
            with patch.object(
                Jac.get_compiler(),
                'get_bytecode',
                side_effect=AssertionError('runtime compiled a prepared module')
            ) {
                a: any = load_prepared_module(applications[0].entry);
                b: any = load_prepared_module(applications[1].entry);
                assert a.b is b;
                for name in names {
                    assert sys.modules[name].initialized;
                }
                assert a.values is not b.values;
                assert a.values == [a.__name__];
                assert b.values == [b.__name__];
            }
        } finally {
            clear();
            for name in list(sys.modules) {
                if any(
                    name == prefix or name.startswith(prefix + '.') for prefix in names
                ) {
                    sys.modules.pop(name, None);
                }
            }
        }
    }
}
