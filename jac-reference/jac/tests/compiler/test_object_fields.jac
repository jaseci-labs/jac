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

test "an aliased ObjectField marker preserves the declared value type" {
    errors = check_fields(
        "import from jaclang.runtime.object_model { ObjectField as declare }\n"
            + "def make_value -> int { return 7; }\n"
            + "obj Example { has value: int = declare(default_factory=make_value); }\n"
            + "def read -> int { return Example().value; }\n"
    );
    assert not errors , str(errors);
}

test "ObjectField markers retain import provenance before type analysis" {
    import from jaclang.compiler.field_semantics { is_field_marker }
    import from jaclang.compiler.frontend.unitree { FuncCall, HasVar }
    program = JacProgram();
    module = program.compile(
        file_path="early_field_marker.jac",
        use_str="import from jaclang.runtime.object_model { ObjectField as declare }\n"
            + "obj Example { has values: list[int] = declare(default_factory=`list); }\n"
            + "def ordinary -> int { return 3; }\n"
            + "obj Other { has value: int = ordinary(); }\n",
        options=CompileOptions(symtab_ir_only=True, need_full_ast=True)
    );
    assert not program.errors_had;
    markers: dict[str, bool] = {};
    for field_var in module.get_all_sub_nodes(HasVar) {
        call = field_var.value;
        assert isinstance(call, FuncCall);
        markers[field_var.name.value] = is_field_marker(call);
    }
    assert markers == {"values": True, "value": False};
}

test "incorrect ObjectField defaults are rejected" {
    errors = check_fields(
        "import from jaclang.runtime.object_model { ObjectField }\n"
            + "obj Example { has value: int = ObjectField(`default='wrong'); }\n"
    );
    assert any("Cannot assign" in error for error in errors) , str(errors);
}

test "incorrect factory return types are rejected" {
    errors = check_fields(
        "import from jaclang.runtime.object_model { ObjectField }\n"
            + "def make_value -> str { return 'wrong'; }\n"
            + "obj Example { has value: int = ObjectField(default_factory=make_value); }\n"
    );
    assert any("Cannot assign" in error for error in errors) , str(errors);
}

test "factories requiring arguments are rejected" {
    errors = check_fields(
        "import from jaclang.runtime.object_model { ObjectField }\n"
            + "def make_value(arg: int) -> int { return arg; }\n"
            + "obj Example { has value: int = ObjectField(default_factory=make_value); }\n"
    );
    assert errors , "An ObjectField factory must be callable without arguments";
}

test "class factories must accept an empty constructor call" {
    for declaration in [
        "obj Item { has required: int; }",
        "class Item { def init(self: Item, required: int) {} }"
    ] {
        errors = check_fields(
            "import from jaclang.runtime.object_model { ObjectField }\n"
                + declaration
                + "\n"
                + "obj Example { has item: Item = ObjectField(default_factory=Item); }\n"
        );
        assert any("required" in error for error in errors) , str(errors);
    }
    errors = check_fields(
        "import from jaclang.runtime.object_model { ObjectField }\n"
            + "obj Item { has value: int = 4; }\n"
            + "obj Example { has item: Item = ObjectField(default_factory=Item), values: list[int] = ObjectField(default_factory=`list); }\n"
    );
    assert not errors , str(errors);
}

test "a same-named ordinary function does not bypass assignment checking" {
    errors = check_fields(
        "def ObjectField -> str { return 'wrong'; }\n"
            + "obj Example { has value: int = ObjectField(); }\n"
    );
    assert any("Cannot assign" in error for error in errors) , str(errors);
}

test "deferred fields are not accepted as constructor arguments" {
    errors = check_fields(
        "import from jaclang.runtime.object_model { ObjectField }\n"
            + "obj Example { has value: int = ObjectField(`init=False); }\n"
            + "def make -> Example { return Example(value=3); }\n"
    );
    assert errors , "An init=False ObjectField must not become a constructor parameter";
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


test "internal ObjectField descriptors remain supported" {
    errors = check_fields(
        "import from jaclang.runtime.object_model { ObjectField }\n"
            + "obj Example { has values: list[int] = ObjectField(default_factory=`list); }\n"
            + "def read -> list[int] { return Example().values; }\n"
    );
    assert not errors , str(errors);
}


test "ordinary object defaults validate without field configuration imports" {
    errors = check_fields(
        "def make_value -> str { return 'wrong'; }\n"
            + "obj Example { has value: int = make_value(); }\n"
    );
    assert any("Cannot assign" in error for error in errors) , str(errors);
}

test "native deferred declaration excludes the constructor parameter" {
    errors = check_fields(
        "obj Example { has value: int postinit; def postinit { self.value = 3; } }\n"
            + "def make -> Example { return Example(value=3); }\n"
    );
    assert errors , "A postinit field must not become a constructor parameter";
}
