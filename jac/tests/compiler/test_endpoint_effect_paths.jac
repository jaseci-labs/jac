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
