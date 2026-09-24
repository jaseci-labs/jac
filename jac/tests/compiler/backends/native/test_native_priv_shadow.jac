"""A module's private function never claims another module's plain name.

E5026 tells a program with two public functions of the same name to mark one
`:priv`. Doing so still broke the importer: forward-declaring an imported
module's private function left it in the importer's plain-name table when the
name was free. The later import of the public function with that name then
looked already declared and was skipped, so the importer's call resolved to the
other module's private (internal) symbol and the linked program failed to load
with an undefined symbol.

Imported private functions are still declared under their module-qualified
symbol, but they no longer occupy the importer's plain name.
"""

import ctypes;
import from tests.support { compile_native, get_func }

test "private helpers do not shadow a same-named public import" {
    (eng, _ir) = compile_native("priv_shadow_main.jac");
    assert get_func(eng, "via_private_helper", ctypes.c_int64)() == 12;
    assert get_func(eng, "via_public_import", ctypes.c_int64)() == 7;
}
