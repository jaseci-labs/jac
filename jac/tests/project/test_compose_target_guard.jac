"""Compile-time guard: compose framework on a web/codegen compile is rejected.

Compose is the Android (Jetpack Compose) surface and has no ES/web lowering, so
it must not be selectable for a web compile. EsastGenPass._ensure_backend rejects
it with E5085 (Android builds lower via ComposeGenPass under no_cgen and never
enter this pass), instead of falling through to an opaque 'unknown framework'.
"""
import tempfile;
import from pathlib { Path }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }


def _error_codes_for_framework(fw: str) -> list[str] {
    tmp = tempfile.mkdtemp(prefix="jac_compose_guard_");
    (Path(tmp) / "jac.toml").write_text(
        '[project]\nname = "demo"\n[placement.pins]\n"*" = "client"\n'
    );
    src = '''
def:pub app() -> JsxElement {
    return <div>"hi"</div>;
}
''';
    path = Path(tmp) / "app.jac";
    path.write_text(src);
    prog = JacProgram();
    prog.compile(str(path), options=CompileOptions(client_framework=fw));
    return [(e.code.code if e.code else "?") for e in prog.errors_had];
}


test "compose framework on a web compile surfaces E5085" {
    codes = _error_codes_for_framework("compose");
    assert "E5085" in codes , codes;
}


test "a web framework on a web compile does not surface E5085" {
    codes = _error_codes_for_framework("react");
    assert "E5085" not in codes , codes;
}
