"""Explicit runtime imports share the kernel used by native walker dispatch."""

import ctypes;
import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from tests.support { compile_native, get_func }
import from jaclang.compiler.frontend.codeinfo {
    OSP_KERNEL_REL,
    OSP_GRAPH_REL,
    kernel_unit_path,
    is_kernel_unit_path,
    native_module_key,
    resolve_native_module
}

test "explicit runtime imports use distinct source unit identities" {
    kernel = kernel_unit_path(OSP_KERNEL_REL);
    graph_path = kernel_unit_path(OSP_GRAPH_REL);
    assert is_kernel_unit_path(kernel);
    assert is_kernel_unit_path(graph_path);
    assert native_module_key(kernel) != native_module_key(graph_path);
    assert not is_kernel_unit_path("/checkout/osp_kernel.jac");
    for (name, path) in [
        ("jaclang.runtime.osp_kernel", kernel),
        ("jaclang.runtime.osp_graph", graph_path)
    ] {
        (_, resolved) = resolve_native_module(name, "/checkout", allow_inferred=False);
        assert resolved == path;
    }
}

test "an imported walker operation acts on the active kernel" {
    (engine, _) = compile_native("osp_runtime_import.jac");
    probe = get_func(engine, "probe", ctypes.c_int64);
    assert probe() == 1;
}

test "a checkout runtime import shares the installed compiler's runtime unit" {
    with tempfile.TemporaryDirectory(prefix="jac-runtime-owner-") as tmp {
        copy_root = Path(tmp);
        package = copy_root / "jaclang";
        (package / "_precompiled").mkdir(parents=True);
        (package / "runtime").mkdir();
        shutil.copy(
            kernel_unit_path(OSP_KERNEL_REL), package / "runtime" / "osp_kernel.jac"
        );
        app = copy_root / "app";
        app.mkdir();
        fixture = Path(__file__).resolve().parent
            / "fixtures"
            / "osp_runtime_import.jac";
        shutil.copy(fixture, app / fixture.name);
        (_, resolved) = resolve_native_module("jaclang.runtime.osp_kernel", str(app));
        assert resolved is not None;
        assert os.path.realpath(resolved)
            == os.path.realpath(kernel_unit_path(OSP_KERNEL_REL));
        (engine, _) = compile_native(fixture.name, fixture_dir=str(app));
        assert get_func(engine, "probe", ctypes.c_int64)() == 1;
    }
}

test "native edge peers require a live edge incident to the origin" {
    (engine, _) = compile_native("osp_edge_peer.jac");
    probe = get_func(engine, "probe", ctypes.c_bool);
    assert probe();
    assert probe();
}
