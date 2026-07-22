"""Entry modules resolve leading-dot relative imports (issue #7661).
Covers both entry paths: plain load and `override_name='__main__'`."""

import sys;
import from pathlib { Path }
import jaclang;
import from jaclang.jac0core.runtime { JacRuntime as Jac }

glob FIXTURE_DIR = str(
         Path(jaclang.__file__).parent / "compiler" / "tests" / "fixtures" / "entry_relative_import"
     );


test "entry module resolves a leading-dot relative import" {
    (module, ) = Jac.jac_import(
        target="relimport_entry", base_path=FIXTURE_DIR, lng="jac"
    );
    assert module.entry_greeting() == "hello from greeter";
}


test "entry loaded as __main__ resolves a leading-dot relative import" {
    saved_main = sys.modules.get('__main__');
    saved_entry = sys.modules.get('relimport_entry');
    try {
        (module, ) = Jac.jac_import(
            target="relimport_entry",
            base_path=FIXTURE_DIR,
            lng="jac",
            override_name="__main__"
        );
        assert module.entry_greeting() == "hello from greeter";
    } finally {
        if saved_main is not None {
            sys.modules['__main__'] = saved_main;
        }
        if saved_entry is not None {
            sys.modules['relimport_entry'] = saved_entry;
        } elif 'relimport_entry' in sys.modules {
            del sys.modules['relimport_entry'];
        }
    }
}
