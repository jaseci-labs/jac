"""User archetypes may reuse the names of the OSP kernel's internal records.

The native OSP kernel is lowered into the same program as the user module and
shares its archetype namespace. The kernel used to declare records with common
names (`Slot`, `Plan`, `Frame`, `WalkScope`, `WalkerDesc`, `NodeDesc`, `Adj`,
`EdgeRow`, `EdgeTypeDesc`). A user `obj Slot` in any module with a walker
replaced the kernel's struct layout, and descriptor setup stored an ability tag
into the user's first field:

    TypeError: cannot store i64 to %"List.i64"**: mismatching types

so the whole module fell back from native lowering. The kernel's records now
carry reserved `Osp` names, and the fixture reuses every former name with a
different layout alongside a walker that exercises descriptors, scopes, frames
and typed-edge adjacency.
"""

import ctypes;
import from tests.support { compile_native, get_func }

test "user archetypes named like former kernel records lower with walkers" {
    (eng, _ir) = compile_native("osp_kernel_type_names.jac");
    tour_total = get_func(eng, "tour_total", ctypes.c_int64);
    shadow_records = get_func(eng, "shadow_records", ctypes.c_int64);
    for _ in range(5) {
        assert tour_total() == 305111;
        assert shadow_records() == 1025;
    }
}
