"""Entry modules resolve leading-dot relative imports (issue #7661)."""

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
