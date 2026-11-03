"""Bound methods preserve Self across union receivers."""
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from tests.support { kernel_check_source }

def check_receiver(source: str) -> list[str] {
    result = kernel_check_source(
        source,
        "self_union_receiver.jac",
        CompileOptions(no_ir_cache=True, force_codespace="server")
    );
    return [f"{diag.code}: {diag.message}" for diag in result.errors];
}

test "paths retain their receiver type when iterating a tuple" {
    errors = check_receiver(
        "import from pathlib { Path }\ndef probe(root_dir: Path, rel: str) -> Path | None {\n for candidate in (root_dir / rel, root_dir / 'fallback') {\n  resolved = candidate.resolve();\n  if root_dir.resolve() not in resolved.parents { continue; }\n  return candidate;\n }\n return None;\n}"
    );
    assert not errors , str(errors);
}

test "Self returns every possible bound receiver" {
    errors = check_receiver(
        "import from typing { Self }\nobj First { has number: int = 0; def copy -> Self { return self; } }\nobj Second { has number: int = 1; def copy -> Self { return self; } }\ndef probe(value: First | Second) -> int { return value.copy().number; }"
    );
    assert not errors , str(errors);
}

test "a Self union retains incompatible member types" {
    errors = check_receiver(
        "import from typing { Self }\nobj First { has number: int = 0; def copy -> Self { return self; } }\nobj Second { has number: str = ''; def copy -> Self { return self; } }\ndef probe(value: First | Second) -> int { return value.copy().number; }"
    );
    assert any("Cannot return" in error for error in errors) , str(errors);
}
