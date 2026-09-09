"""Explicit runtime imports share the kernel used by native walker dispatch."""

import ctypes;
import os;
import from tests.support { JAC_ROOT, compile_native, get_func }
import from jaclang.compiler.backends.common.kernel_units { kernel_unit_owner }

test "runtime unit identity is independent of the compiler installation" {
    assert kernel_unit_owner(os.path.join(JAC_ROOT, "jaclang/runtime/osp_kernel.jac"))
        == "osp_kernel";
    assert kernel_unit_owner(
        "/checkout/jaclang/runtime/osp_kernel.jac", "jaclang.runtime.osp_kernel"
    )
        == "osp_kernel";
    assert kernel_unit_owner(
        "/checkout/jaclang/runtime/osp_graph.jac", "jaclang.runtime.osp_graph"
    )
        == "osp_kernel";
    assert kernel_unit_owner("/checkout/osp_kernel.jac", "app.osp_kernel") == "";
}

test "an imported walker operation acts on the active kernel" {
    (engine, _) = compile_native("osp_runtime_import.jac");
    address = engine.get_function_address("probe");
    assert address != 0;
    probe = ctypes.CFUNCTYPE(ctypes.c_int64)(address);
    assert probe() == 1;
}

test "native edge peers require a live edge incident to the origin" {
    (engine, _) = compile_native("osp_edge_peer.jac");
    probe = get_func(engine, "probe", ctypes.c_bool);
    assert probe();
    assert probe();
}
