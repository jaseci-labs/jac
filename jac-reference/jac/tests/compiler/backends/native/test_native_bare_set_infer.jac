"""An empty set built with `set()` infers its element type from its adds.

`seen: set = set()` (or an unannotated `seen = set()`) filled by
`seen.add(key)` used to keep an unknown element type, which native lowers
to raw integer slots, so adding a string refused to lower ('set add').
The type evaluator now infers the element type of an empty `set()` from
the `add`, `update` and `|=` mutations of its binding, as it already did
for an empty `[]` from `append`/`insert`/`extend`, and a bare `set`
annotation adopts that inferred type as the empty `[]` case already did.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "sets filled after set() lower natively and match Python" {
    source = str(Path(__file__).resolve().parent / "fixtures" / "bare_set_infer.jac");
    out = assert_native_identity(source, profiles=["managed", "rc"]);
    assert out.splitlines()[0] == "['k0', 'k1', 'k2', 'k3']" , out;
}
