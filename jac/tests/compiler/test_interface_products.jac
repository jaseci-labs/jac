"""Interfaces describe exports independently of later body analysis."""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.passes.rc_facts_pass { RcFactsPass }
import from jaclang.compiler.types.stubcat.modiface { build_module_iface }
import from jaclang.compiler.types.stubcat.locate { jaclang_pkg_dir }
import from jaclang.compiler.types.types { FunctionType, UnknownType }

test "body lifetime analysis does not change the exported interface" {
    with TemporaryDirectory() as directory {
        source = Path(directory) / "library.jac";
        source.write_text(
            "glob values: list[int] = [42];\n"
                + "def answer() -> int { return values[0]; }\n"
        );
        program = JacProgram();
        module = program.compile(
            str(source), options=CompileOptions(no_cgen=True, no_ir_cache=True)
        );
        assert not program.errors_had;
        evaluator = program.get_type_evaluator();
        before = build_module_iface(module, evaluator, jaclang_pkg_dir());
        program.run_schedule(module, [RcFactsPass]);
        symbol = module.lookup("values");
        assert symbol is not None;
        assert symbol.na_escapes;
        after = build_module_iface(module, evaluator, jaclang_pkg_dir());
        assert before == after , "local lifetime facts changed the interface digest";
    }
}

test "equivalent unknown types produce identical interface bytes" {
    with TemporaryDirectory() as directory {
        source = Path(directory) / "library.jac";
        source.write_text(
            "def choose(left: any, right: any) -> any { return left; }\n"
        );
        program = JacProgram();
        module = program.compile(
            str(source), options=CompileOptions(no_cgen=True, no_ir_cache=True)
        );
        assert not program.errors_had;
        evaluator = program.get_type_evaluator();
        symbol = module.lookup("choose");
        assert symbol is not None;
        function = evaluator.get_type_of_symbol(symbol);
        assert isinstance(function, FunctionType);
        parameters = function.parameters;
        assert parameters is not None and len(parameters) == 2;
        unknown = UnknownType(is_diagnosed=True, is_incomplete=True);
        parameters[0].param_type = unknown;
        parameters[1].param_type = unknown;
        shared = build_module_iface(module, evaluator, jaclang_pkg_dir());
        parameters[1].param_type = UnknownType(is_diagnosed=True, is_incomplete=True);
        distinct = build_module_iface(module, evaluator, jaclang_pkg_dir());
        assert shared == distinct , "interface bytes depended on unknown-type object sharing";
        parameters[1].param_type = UnknownType(is_diagnosed=True, is_incomplete=False);
        assert distinct != build_module_iface(module, evaluator, jaclang_pkg_dir());
        parameters[1].param_type = UnknownType(is_diagnosed=False, is_incomplete=True);
        assert distinct != build_module_iface(module, evaluator, jaclang_pkg_dir());
    }
}
