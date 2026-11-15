"""Imports a name its Jac source module does not define.

`missing_table` feeds a glob initializer the way a clinic method table fed a
type definition: before the fix the native build bound it to nothing and the
initializer received a null list.
"""

import from missing_import_lib { present_table, present_fn, missing_table }

obj TypeDef {
    has name: str,
        table: list[int];
}

glob tdef: TypeDef = TypeDef(name="select.poll", table=missing_table);

with entry {
    print(tdef.name, len(tdef.table), len(present_table), present_fn(1));
}
