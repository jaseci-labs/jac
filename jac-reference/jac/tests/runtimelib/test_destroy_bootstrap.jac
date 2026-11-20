import sys;
import importlib;
import from unittest.mock { patch }
import from jaclang { JacRuntime as Jac }
import from jaclang.compiler.driver.compiler { JacCompiler }

test "deleting ordinary values does not import graph cleanup modules" {
    # Cache invalidation can delete values while these modules are importing.
    # Ordinary Python values must not re-enter graph or region initialization.
    with patch.dict(
        sys.modules,
        {"jaclang.runtime.region": None, "jaclang.runtime.osp_kernel": None}
    ) {
        Jac.destroy({"discarded": 42});
        Jac.destroy([]);
    }
}

test "region cleanup imports without invoking the full compiler" {
    with patch.dict(sys.modules) {
        sys.modules.pop("jaclang.runtime.region", None);
        with patch.object(
            JacCompiler,
            "get_bytecode",
            side_effect=AssertionError("region cleanup re-entered the compiler")
        ) {
            region = importlib.import_module("jaclang.runtime.region");
            region.run_drop(object());
        }
    }
}
