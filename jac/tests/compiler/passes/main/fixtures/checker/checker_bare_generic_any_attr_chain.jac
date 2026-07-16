"""Attribute access on a bare-generic-default `any` must propagate as
trusted `any`, not stop at Unknown.

`build_type_var_solution` substitutes `AnyType(is_foreign=True)` for a
bare generic's unresolved type params (e.g. `dict`'s `_KT`/`_VT`), reusing
the same flag that marks `any` originating from untyped Python/JS
interop. That flag is also read by attribute-access resolution
(`type_evaluator.impl.jac:645-648`) to propagate "trust this, don't
strict-check further" through `.attr` chains. So `d["n"].bit_length`
below must resolve to `any` end-to-end, the same way it would if `d["n"]`
had come from an untyped import -- not fall through to Unknown with a
spurious W1051, which was the behavior before bare-generic defaults were
marked foreign.
"""

with entry {
    rows: list[dict] = [{"n": 1}];
    d: dict = rows[0];

    v = d["n"];
    w = v.bit_length;

    print(w);
}
