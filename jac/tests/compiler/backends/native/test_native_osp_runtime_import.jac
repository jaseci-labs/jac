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

test "constructed edge expressions retain their native graph type" {
    (engine, _) = compile_native("osp_edge_instance.jac");
    probe = get_func(engine, "probe", ctypes.c_int64);
    assert probe() == 1;
    assert probe() == 1;
    generic_edge = get_func(engine, "generic_edge", ctypes.c_int64);
    assert generic_edge() == 1;
    assert generic_edge() == 1;
}

test "typed graph queries preserve object identity through union returns" {
    (engine, _) = compile_native("osp_query_union.jac");
    probe = get_func(engine, "probe", ctypes.c_bool);
    assert probe();
    assert probe();
    erased = get_func(engine, "erased_identity", ctypes.c_bool);
    assert erased();
    assert erased();
    filtered = get_func(engine, "filtered_identity", ctypes.c_bool);
    assert filtered();
    assert filtered();
    disconnected = get_func(
        engine, "disconnected_references", ctypes.c_bool, ctypes.c_bool
    );
    assert disconnected(False);
    assert disconnected(True);
    visited = get_func(engine, "visited_references", ctypes.c_int64, ctypes.c_bool);
    assert visited(False) == 73;
    assert visited(True) == 73;
    retained = get_func(engine, "retained", ctypes.c_bool);
    assert retained();
    assert retained();
    regional = get_func(engine, "regional_references", ctypes.c_bool);
    read_drops = get_func(engine, "read_drops", ctypes.c_int64);
    for _ in range(3) {
        assert regional();
        assert read_drops() == 1;
    }
}

test "native node retirement removes stale region membership before handle reuse" {
    (engine, _) = compile_native("osp_region_reuse.jac");
    probe = get_func(engine, "probe", ctypes.c_bool);
    assert probe();
    assert probe();
}
