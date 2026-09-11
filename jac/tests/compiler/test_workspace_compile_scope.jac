"""An explicit file compiles without reading unrelated applications or tests."""

import builtins;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import from jaclang.compiler.driver.jir { module_env_fingerprint }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.project.config { get_explicit_config, set_config }

test "a file's cache fingerprint and compilation stay within its imports (#9095)" {
    saved = get_explicit_config();
    set_config(None);
    try {
        with TemporaryDirectory() as directory {
            base = Path(directory);
            (base / "jac.toml").write_text(
                '[project]\nname = "scope"\ndefault-app = "web"\n'
                '[apps.web]\nkind = "web-app"\nentry-point = "web"\n'
                '[apps.api]\nkind = "service"\nentry-point = "api"\n'
            );
            for name in ["web", "api", "unrelated_test"] {
                (base / (name + ".jac")).write_text(
                    'def unrelated -> int { return 42; }\n'
                );
            }
            target = base / "hello.jac";
            target.write_text('with entry { print("hi"); }\n');
            forbidden = {
                str(base / (name + ".jac")) for name in ["web", "api", "unrelated_test"]
            };
            program = JacProgram();
            with patch("builtins.open", wraps=builtins.open) as opened {
                module_env_fingerprint(str(target));
                program.compile(str(target));
            }
            assert not program.errors_had , "\n".join(
                str(error) for error in program.errors_had
            );
            unexpected = {
                str(call.args[0])
                for call in opened.call_args_list
                if call.args and str(call.args[0]) in forbidden
            };
            assert not unexpected , f"unrelated source was read: {unexpected}";
        }
    } finally {
        set_config(saved);
    }
}
