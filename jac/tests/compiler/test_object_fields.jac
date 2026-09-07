"""Field declarations validate values and synthesized constructor contracts."""
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

def check_fields(source: str) -> list[str] {
    program = JacProgram();
    program.compile(
        file_path="object_field_contract.jac",
        use_str=source,
        options=CompileOptions(no_cgen=True, no_ir_cache=True, force_codespace="server")
    );
    return [str(alert) for alert in program.errors_had];
}

test "an aliased field marker preserves the declared value type" {
    errors = check_fields(
        "import from jaclang.runtime.object_model { field as declare }\n"
            + "def make_value -> int { return 7; }\n"
            + "obj Example { has value: int = declare(default_factory=make_value); }\n"
            + "def read -> int { return Example().value; }\n"
    );
    assert not errors , str(errors);
}

test "incorrect field defaults are rejected" {
    errors = check_fields(
        "import from jaclang.runtime.object_model { field }\n"
            + "obj Example { has value: int = field(`default='wrong'); }\n"
    );
    assert any("Cannot assign" in error for error in errors) , str(errors);
}

test "incorrect factory return types are rejected" {
    errors = check_fields(
        "import from jaclang.runtime.object_model { field }\n"
            + "def make_value -> str { return 'wrong'; }\n"
            + "obj Example { has value: int = field(default_factory=make_value); }\n"
    );
    assert any("Cannot assign" in error for error in errors) , str(errors);
}

test "factories requiring arguments are rejected" {
    errors = check_fields(
        "import from jaclang.runtime.object_model { field }\n"
            + "def make_value(arg: int) -> int { return arg; }\n"
            + "obj Example { has value: int = field(default_factory=make_value); }\n"
    );
    assert errors , "A field factory must be callable without arguments";
}

test "a same-named ordinary function does not bypass assignment checking" {
    errors = check_fields(
        "def field -> str { return 'wrong'; }\n"
            + "obj Example { has value: int = field(); }\n"
    );
    assert any("Cannot assign" in error for error in errors) , str(errors);
}

test "deferred fields are not accepted as constructor arguments" {
    errors = check_fields(
        "import from jaclang.runtime.object_model { field }\n"
            + "obj Example { has value: int = field(`init=False); }\n"
            + "def make -> Example { return Example(value=3); }\n"
    );
    assert errors , "An init=False field must not become a constructor parameter";
}

test "property setters can accept an optional value while getters remain precise" {
    errors = check_fields(
        "obj Example { has value: int { getter { return 3; } "
            + "setter(value: int | None) {} } }\n"
            + "def update -> int { item = Example(); item.value = None; return item.value + 1; }\n"
    );
    assert not errors , str(errors);
}

test "property writes use the setter parameter rather than the getter result" {
    errors = check_fields(
        "obj Example { has value: int | str { getter { return 3; } "
            + "setter(value: int) {} } }\n"
            + "def update { item = Example(); item.value = 'wrong'; }\n"
    );
    assert any("Cannot assign" in error for error in errors) , str(errors);
}
