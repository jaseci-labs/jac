"""Regression coverage for relative imports in an entry module (issue #7661).

`jac start` loads the entry through `Jac.jac_import(...)` *without*
`override_name='__main__'`. That path used to hand the module straight to
`importlib.import_module`, which creates a plain top-level module with no
`__path__`. A module with no `__path__` is not a package, so its `__package__`
is empty and a leading-dot import inside it raised

    attempted relative import with no known parent package

even though `jac check` reported the file clean. `jac run` hid the problem
because it executes through the native backend and never touches this loader.

This pins the invariant: an entry module loaded the way `jac start` loads it can
resolve `import from .services.greeter { greet }`.
"""

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
