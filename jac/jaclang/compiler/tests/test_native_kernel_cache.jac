"""Fresh native builds bypass persisted runtime units through the unit registry."""
import os;
import tempfile;
import from pathlib { Path }
import from unittest.mock { patch }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.nativecache { NativeUnitEntry }
import from jaclang.compiler.driver.native_iface { NativeIface }

test "explicit fresh compilation bypasses persisted native units" {
    with tempfile.TemporaryDirectory() as directory {
        path = os.path.join(directory, "unit.jac");
        Path(path).write_text("def answer -> int { return 42; }");
        registry = JacProgram().native_units();
        options = CompileOptions();
        unit = NativeUnitEntry(
            path=path,
            digest="unit",
            iface=NativeIface(),
            stamp=registry.stamp_for(options)
        );
        with patch.object(registry, "_read_from_disk", return_value=unit) as load, patch.object(
            registry, "compile_unit", return_value=unit
        ) as compile {
            assert registry.ensure(path, options=options) is unit;
            load.assert_called_once();
            compile.assert_not_called();
            load.reset_mock();
            options.no_ir_cache = True;
            assert registry.ensure(path, options=options) is unit;
            load.assert_not_called();
            compile.assert_called_once_with(os.path.realpath(path), options);
            assert options.clone_for_native_import().no_ir_cache;
        }
    }
}
