"""Prelude exports are read from the same module tree as other compiler facts."""
import ast;
import from jaclang.compiler.frontend.module_facts { ModuleFacts }
import from jaclang.compiler.frontend.parser.frontend { parse }
import from jaclang.compiler.frontend.unitree { Module, PythonModuleAst, Source }
import from jaclang.compiler.passes.pyast_load_pass { PyastBuildPass }

def jac_module(source: str) -> Module {
    (module, failed) = parse(source, "module_exports.jac");
    assert not failed;
    return module;
}

test "missing and empty export declarations remain distinct" {
    assert ModuleFacts.literal_exports(jac_module("glob value = 1;")) is None;
    assert ModuleFacts.literal_exports(jac_module("glob __all__ = [];")) == set();
}

test "literal exports preserve text and ignore non-string entries" {
    module = jac_module(
        "glob __all__ = ['first', 'joined' 'name', 'first', 3, b'bytes'];"
    );
    assert ModuleFacts.literal_exports(module) == {'first', 'joinedname'};
}

test "nested export declarations do not replace module exports" {
    module = jac_module("glob __all__ = ['outer']; def inner { __all__ = ['inner']; }");
    assert ModuleFacts.literal_exports(module) == {'outer'};
}

test "exported imports retain aliases and accumulate repeated modules" {
    module = jac_module(
        "import from first { A as Alias, Hidden } "
            + "import from first { B } import from second { C } "
            + "glob __all__ = ['Alias', 'B', 'C'];"
    );
    assert ModuleFacts.exported_import_names(module)
        == {'first': {'Alias', 'B'}, 'second': {'C'}};
}

test "Python stub trees use the same export extraction" {
    source = "from first import A as Alias, Hidden\n"
        + "from first import B\nfrom second import C\n"
        + "__all__ = ('Alias', 'B', 'C', 3)\n";
    module = PyastBuildPass(
        ir_in=PythonModuleAst(
            ast.parse(source), orig_src=Source(source, "module_exports.pyi")
        )
    ).ir_out;
    assert ModuleFacts.literal_exports(module) == {'Alias', 'B', 'C'};
    assert ModuleFacts.exported_import_names(module)
        == {'first': {'Alias', 'B'}, 'second': {'C'}};
}
