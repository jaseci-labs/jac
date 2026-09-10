"""Colocated apps load distinct copies of shared Jac modules from prepared code."""
import builtins;
import sys;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import from jaclang.runtime.prepared {
    PreparedApplication,
    publish,
    clear,
    load_prepared_module,
    application_namespace
}
import from jaclang.runtime.runtime { JacRuntime as Jac }

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
