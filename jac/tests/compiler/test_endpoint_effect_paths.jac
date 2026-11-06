"""Effect declarations retain their identity in relocated compiler interfaces."""

import os;
import tempfile;
import from unittest.mock { PropertyMock, patch }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.srcloc { CodeLocInfo }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.passes.endpoint_effect_pass { EndpointEffectPass }
import from jaclang.compiler.passes.execution { new_context }

test "effects decorators accept package-relative and relocated module paths" {
    with tempfile.TemporaryDirectory() as temporary {
        path = os.path.join(temporary, "main.jac");
        with open(path, "w") as source {
            source.write(
                "import from jaclang.lib.effects { effects }\n"
                "@effects(reads=[\"Note\"], writes=[])\n"
                "def read_data -> int { return 1; }\n"
            );
        }
        program = JacProgram();
        module = program.compile(path);
        declarations = [
            ability
            for ability in module.get_all_sub_nodes(uni.Ability)
            if ability.sym_name == "read_data"
        ];
        assert len(declarations) == 1;
        classifier = EndpointEffectPass(
            module=module, ctx=new_context(EndpointEffectPass, module, prog=program)
        );
        for module_path in [
            "jaclang/lib/effects.jac",
            "/opt/jac/jaclang/lib/effects.jac",
            "jaclang\\lib\\effects.jac",
            "C:\\Jac\\jaclang\\lib\\effects.jac"
        ] {
            with patch.object(
                CodeLocInfo,
                "mod_path",
                new_callable=PropertyMock,
                return_value=module_path
            ) {
                result = classifier._declaration_effects(declarations[0]);
                assert result == {"reads": ["Note"], "writes": []} , module_path;
            }
        }
        for module_path in ["notjaclang/lib/effects.jac", "/custom/effects.jac"] {
            with patch.object(
                CodeLocInfo,
                "mod_path",
                new_callable=PropertyMock,
                return_value=module_path
            ) {
                assert classifier._declaration_effects(declarations[0]) is None;
            }
        }
    }
}


test "aliased effects imports retain declared read metadata" {
    with tempfile.TemporaryDirectory() as temporary {
        path = os.path.join(temporary, "main.jac");
        with open(path, "w") as source {
            source.write(
                "import from jaclang.lib.effects { effects as declared }\n"
                "node Item {}\n"
                "@declared(reads=[\"Item\"], writes=[])\n"
                "def read_items(holder: Root) -> list[Item] { return [holder-->[?:Item]]; }\n"
                "walker:pub ReadItems { can go with Root entry { report read_items(here); } }\n"
            );
        }
        for _ in range(2) {
            program = JacProgram();
            module = program.compile(path);
            classifier = EndpointEffectPass(
                module=module, ctx=new_context(EndpointEffectPass, module, prog=program)
            );
            helpers = [
                ability
                for ability in module.get_all_sub_nodes(uni.Ability)
                if ability.sym_name == "read_items"
            ];
            assert len(helpers) == 1;
            assert classifier._declaration_effects(helpers[0])
                == {"reads": ["Item"], "writes": []};
            values = list(module.gen.interop_manifest.endpoint_effects.values());
            assert len(values) == 1;
            summary = values[0];
            assert summary["unknown"] is False , str(summary);
            assert summary["writes"] == [] , str(summary);
            assert summary["reads"] == ["*"] , str(summary);
            assert summary["assumptions"] , str(summary);
        }
    }
}

test "catalog decorator symbols retain effect declarations without Ability trees" {
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.compiler.types.stubcat.locate { jaclang_pkg_dir }
    import from jaclang.compiler.types.stubcat.writer { build_module_iface }
    import from jaclang.compiler.types.stubcat.modiface {
        open_module_iface,
        iface_module
    }
    pkg = jaclang_pkg_dir();
    program = JacProgram();
    source = program.compile(
        os.path.join(pkg, "lib", "effects.jac"),
        options=CompileOptions(no_cgen=True, symtab_ir_only=True, need_full_ast=True)
    );
    payload = build_module_iface(source, program.get_type_evaluator(), pkg);
    catalog = open_module_iface(payload, pkg);
    assert catalog is not None;
    cached = iface_module(catalog);
    assert cached is not None;
    symbol = cached.lookup("effects");
    assert symbol is not None;
    assert uni.ability_of_symbol(symbol) is None;
    with tempfile.TemporaryDirectory() as temporary {
        path = os.path.join(temporary, "main.jac");
        with open(path, "w") as output {
            output.write(
                "import from jaclang.lib.effects { effects }\n"
                "@effects(reads=[\"Note\"], writes=[])\n"
                "def read_data -> int { return 1; }\n"
            );
        }
        module = program.compile(path);
        helpers = [
            ability
            for ability in module.get_all_sub_nodes(uni.Ability)
            if ability.sym_name == "read_data"
        ];
        assert len(helpers) == 1;
        classifier = EndpointEffectPass(
            module=module, ctx=new_context(EndpointEffectPass, module, prog=program)
        );
        # The resolver returns this real serialized-interface symbol on a
        # warm import; its declaration is a Name under a CatModule.
        with patch.object(classifier, "_call_target_symbol", return_value=symbol) {
            assert classifier._declaration_effects(helpers[0])
                == {"reads": ["Note"], "writes": []};
        }
    }
}
