"""Module initializers run in import order, and across an import cycle in the
order their globals are read.

A native program runs every unit's module initializer before its entry. The
link plan ordered units dependencies first, but inside an import cycle by
path, so a module whose glob initializer read another module's list glob could
run first and read it unset (JacPython's `_multiprocessing` SemLock type
definition read the member table of the module half and segfaulted). The
initializers now run as Python runs module bodies, a depth-first import walk
from the root, and a unit whose initializer reads globals another unit
computes runs after that unit. Initializers that read each other's globals
fail the link plan with the reads named.
"""

import os;
import from tests.support { TESTS_DIR, assert_native_identity }
import from jaclang.compiler.backends.native.link_plan {
    LinkPlanError,
    LinkUnit,
    initialization_order
}
import from jaclang.compiler.driver.native_iface { NativeIface }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "glob_init_order"
     );

def unit(
    name: str,
    deps: list[str],
    computes: list[str] = [],
    reads: list[str] = [],
    is_root: bool = False
) -> LinkUnit {
    iface = NativeIface(
        module=name,
        prefix=name,
        deps=[f"/units/{d}.jac" for d in deps],
        runtime_globals=computes,
        init_reads=reads
    );
    return LinkUnit(
        path=f"/units/{name}.jac",
        prefix=name,
        iface=iface,
        digest=name,
        is_root=is_root
    );
}

def order_of(units: list[LinkUnit]) -> list[str] {
    return [
        os.path.basename(u.path)[:-4]
        for u in initialization_order(units, ["/units/main.jac"])
    ];
}

test "initializers follow the import walk from the root" {
    units = [
        unit("base", []),
        unit("left", ["base"]),
        unit("right", ["base"]),
        unit("main", ["right", "left"], is_root=True)
    ];
    assert order_of(units) == ["base", "right", "left", "main"];
}

test "inside an import cycle a unit runs after the globals its initializer reads" {
    # `main` imports `table` first, so the walk alone would start `holder`
    # inside the cycle before `table`; `holder` reads `table.MEMBERS`.
    units = [
        unit("holder", ["table"], computes=["holder.SPEC"], reads=["table.MEMBERS"]),
        unit("table", ["holder"], computes=["table.MEMBERS"]),
        unit("main", ["table", "holder"], is_root=True)
    ];
    assert order_of(units) == ["table", "holder", "main"];
}

test "reads of globals no initializer computes do not order units" {
    units = [
        unit("holder", ["table"], reads=["table.LIMIT", "PyExc_TypeError"]),
        unit("table", ["holder"]),
        unit("main", ["holder"], is_root=True)
    ];
    assert order_of(units) == ["table", "holder", "main"];
}

test "initializers that read each other's globals fail the plan" {
    units = [
        unit("holder", ["table"], computes=["holder.COUNT"], reads=["table.MEMBERS"]),
        unit("table", ["holder"], computes=["table.MEMBERS"], reads=["holder.COUNT"]),
        unit("main", ["holder"], is_root=True)
    ];
    message = "";
    try {
        order_of(units);
    } except LinkPlanError as err {
        message = str(err);
    }
    assert "holder.jac reads MEMBERS of table.jac" in message , message;
    assert "table.jac reads COUNT of holder.jac" in message , message;
}

test "a glob initializer reads another module's list glob across a cycle" {
    # A nogc build keeps no heap value in a global (E1406), so the list glob
    # runs under the reference-counted profiles and the Python backend.
    out = assert_native_identity(
        os.path.join(FIXTURES, "main.jac"), profiles=["rc", "managed"]
    );
    assert out.split("\n")[:2] == ["SemLock 3 3 SemLock:3", "handle 0"] , out;
}

test "computed scalar globals are read across a cycle under every profile" {
    out = assert_native_identity(os.path.join(FIXTURES, "scalar_main.jac"));
    assert out == "76 9 3x24\n" , out;
}
