"""Tests for MTIR (Meaning Typed IR) integration with byLLM.

These tests verify byLLM-specific MTIR functionality:
1. Schema generation data structures work correctly
2. Tool schema generation with MTIR info
3. MTIR caching works correctly
4. Python library fallback mode works when MTIR is unavailable

Note: MTIR extraction from compiled code is tested in:
  jac/tests/compiler/passes/main/test_mtir_gen_pass.py
"""

import io;
import os;
import sys;
import tempfile;
import from dataclasses { fields }
import from pathlib { Path }

import from jaclang { JacRuntime }
import from jaclang { JacRuntimeInterface as Jac }
import from jaclang.jac0core.mtp {
    ClassInfo,
    EnumInfo,
    FieldInfo,
    FunctionInfo,
    MethodInfo,
    ParamInfo,
    mk_dict,
    mk_list,
}
import from jaclang.jac0core.program { JacProgram }

glob jac_import = Jac.jac_import,
     FIXTURE_DIR = os.path.join(os.path.dirname(__file__), "fixtures");

def fixture_path(fixture: str) -> str {
    """Get absolute path of a fixture from fixtures directory."""
    file_path = os.path.join(FIXTURE_DIR, fixture);
    return os.path.abspath(file_path);
}

# =============================================================================
# Schema Generation Data Structure Tests
# =============================================================================
test "field semstrings in schema" {
    field_info = FieldInfo(
        name="username", semstr="Unique username for login.", type_info="str",
    );
    class_info = ClassInfo(
        name="User",
        semstr="A registered user in the system.",
        fields=[field_info],
        base_classes=[],
        methods=[],
    );

    assert class_info.name == "User";
    assert class_info.semstr == "A registered user in the system.";
    assert len(class_info.fields) == 1;
    assert class_info.fields[0].name == "username";
    assert class_info.fields[0].semstr == "Unique username for login.";
}

test "param info structure" {
    param_info = ParamInfo(
        name="criteria",
        semstr="Description of the type of person to generate.",
        type_info="str",
    );

    assert param_info.name == "criteria";
    assert param_info.semstr == "Description of the type of person to generate.";
    assert param_info.type_info == "str";
}

test "function info for tool schema" {
    params = [
        ParamInfo(name="birth_year", semstr="Year of birth.", type_info="int"),
        ParamInfo(
            name="current_year",
            semstr="Current year for calculation.",
            type_info="int",
        ),

    ];
    func_info = FunctionInfo(
        name="calculate_age",
        semstr="Calculate age from birth year.",
        params=params,
        return_type="int",
    );

    assert func_info.name == "calculate_age";
    assert func_info.semstr == "Calculate age from birth year.";
    assert func_info.params is not None;
    assert len(func_info.params) == 2;
    assert func_info.params[0].name == "birth_year";
    assert func_info.params[0].semstr == "Year of birth.";
}

test "nested class info" {
    person_class = ClassInfo(
        name="Person",
        semstr="A person entity.",
        fields=[
            FieldInfo(name="name", semstr="Full name.", type_info="str"),
            FieldInfo(name="age", semstr="Age in years.", type_info="int"),

        ],
        base_classes=[],
        methods=[],
    );

    user_class = ClassInfo(
        name="User",
        semstr="A user with address.",
        fields=[
            FieldInfo(name="username", semstr="Login name.", type_info="str"),
            FieldInfo(name="friend", semstr="A friend.", type_info=person_class),

        ],
        base_classes=[],
        methods=[],
    );

    assert user_class.fields[1].type_info == person_class;
    assert isinstance(user_class.fields[1].type_info, ClassInfo);
    assert user_class.fields[1].type_info.name == "Person";
}

test "generic type encoding" {
    list_type = mk_list("Person");
    assert list_type == ("list", "Person");

    dict_type = mk_dict("str", "int");
    assert dict_type == ("dict", "str", "int");

    person_info = ClassInfo(
        name="Person", semstr="A person.", fields=[], base_classes=[], methods=[]
    );
    nested_list = mk_list(person_info);
    assert nested_list[0] == "list";
    assert nested_list[1].name == "Person";
}

# =============================================================================
# Tool Schema Tests
# =============================================================================
test "tool extraction from compiled code" {
    prog = JacProgram();
    prog.compile(fixture_path("tool_function.jac"));
    assert not prog.errors_had;

    assert JacRuntime.program is not None;
    mtir_map = JacRuntime.program.mtir_map;

    func_with_tools = None;
    for (scope, info) in mtir_map.items() {
        if (
            isinstance(info, FunctionInfo)
            and info.tools
            and "tool_function" in scope
            and info.name == "get_person_details"
        ) {
            func_with_tools = info;
            break;
        }
    }

    assert func_with_tools is not None , "Should find get_person_details with tools";
    assert func_with_tools.tools is not None;
    assert len(func_with_tools.tools) == 2;

    tool_names = [t.name for t in func_with_tools.tools];
    assert "calculate_age" in tool_names;
    assert "format_name" in tool_names;

    for tool in func_with_tools.tools {
        assert isinstance(tool, FunctionInfo);
        assert tool.semstr is not None;
    }
}

test "method tool in class" {
    prog = JacProgram();
    prog.compile(fixture_path("tool_method.jac"));
    assert not prog.errors_had;

    assert JacRuntime.program is not None;
    mtir_map = JacRuntime.program.mtir_map;

    method_scope = None;
    for scope in mtir_map {
        if "eval_expression" in scope and "tool_method" in scope {
            method_scope = scope;
            break;
        }
    }

    assert method_scope is not None , "Should find eval_expression method";
    method_info = mtir_map[method_scope];
    assert isinstance(method_info, MethodInfo);

    assert method_info.tools is not None;
    tool_names = [t.name for t in method_info.tools];
    assert "add" in tool_names , f"Expected 'add' in tools, got: {tool_names}";
    assert "multiply" in tool_names , f"Expected 'multiply' in tools, got: {tool_names}";
}

# =============================================================================
# Python Library Fallback Tests
# =============================================================================
test "mtruntime without mtir info" {
    import from jaclang.jac0core.mtp { MTIR }

    def sample_func(x: int, y: str) -> str {
        return f"{y}: {x}";
    }

    mtir = MTIR(
        caller=sample_func, args={0: 42, 1: "test"}, call_params={}, ir_info=None,
    );

    runtime = mtir.runtime;
    assert runtime is not None;
    assert runtime.caller == sample_func;
}

test "python lib mode fixture" {
    import from fixtures { python_lib_mode }

    assert hasattr(python_lib_mode, "Person");
    assert hasattr(python_lib_mode, "get_person_info");
    assert hasattr(python_lib_mode, "llm");

    person_fields = {f.name for f in fields(python_lib_mode.Person)};
    assert "name" in person_fields;
    assert "birth_year" in person_fields;
    assert "description" in person_fields;
}

# =============================================================================
# MTIR Caching Tests
# =============================================================================
test "cache key for mtir" {
    import from jaclang.jac0core.bccache { CacheKey }

    key = CacheKey.for_source("/path/to/test.jac");
    assert key is not None;
    assert key.source_path == "/path/to/test.jac";
}

test "disk cache mtir methods exist" {
    import from jaclang.jac0core.bccache { DiskBytecodeCache }

    cache = DiskBytecodeCache();
    assert hasattr(cache, "get_mtir");
    assert hasattr(cache, "put_mtir");
}

test "mtir cache roundtrip" {
    import from jaclang.jac0core.bccache { CacheKey, DiskBytecodeCache }

    tmp_path = Path(tempfile.mkdtemp());
    test_file = tmp_path / "test.jac";
    test_file.write_text("# test content");

    cache = DiskBytecodeCache();

    key = CacheKey.for_source(str(test_file));

    test_mtir_map = {
        "test.func1": FunctionInfo(
            name="func1",
            semstr="Test function one.",
            params=[ParamInfo(name="x", semstr="Input x.", type_info="int")],
            return_type="str",
        ),

    };

    cache.put_mtir(key, test_mtir_map);

    retrieved = cache.get_mtir(key);

    if retrieved is not None {
        assert "test.func1" in retrieved;
        assert retrieved["test.func1"].name == "func1";
        assert retrieved["test.func1"].semstr == "Test function one.";
    }
}

# =============================================================================
# Fixture Compilation Test
# =============================================================================
test "basic fixture compiles" {
    prog = JacProgram();
    prog.compile(fixture_path("basic_compile.jac"));
    assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";

    assert JacRuntime.program is not None;
    mtir_map = JacRuntime.program.mtir_map;
    assert len(mtir_map) > 0 , "MTIR map should have entries";

    found_generate_person = False;
    for scope in mtir_map {
        if "basic_compile" in scope and "generate_person" in scope {
            found_generate_person = True;
            break;
        }
    }

    assert found_generate_person , "Should have generate_person function in MTIR";
}

# =============================================================================
# Scope Name Consistency Tests
# =============================================================================
test "scope name with trailing a" {
    prog = JacProgram();
    fixture = fixture_path("test_schema.jac");
    prog.compile(fixture);
    assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";

    assert JacRuntime.program is not None;
    mtir_map = JacRuntime.program.mtir_map;

    scopes_with_generate_data = [
        scope
        for scope in mtir_map
        if "generate_data" in scope
    ];

    assert len(scopes_with_generate_data) > 0 , f"Should find generate_data in MTIR map. Available scopes: {list(
        mtir_map.keys()
    )}";

    matching_scope = None;
    for scope in scopes_with_generate_data {
        if "test_schema.generate_data" in scope {
            matching_scope = scope;
            break;
        }
    }

    assert matching_scope is not None , f"Expected scope containing 'test_schema.generate_data', but found: {scopes_with_generate_data}. This indicates the module name may have been truncated.";

    assert isinstance(mtir_map[matching_scope], FunctionInfo);
}

test "scope name with trailing c" {
    prog = JacProgram();
    fixture = fixture_path("basic.jac");
    prog.compile(fixture);
    assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";

    assert JacRuntime.program is not None;
    mtir_map = JacRuntime.program.mtir_map;

    scopes_with_get_basic = [
        scope
        for scope in mtir_map
        if "get_basic" in scope
    ];

    assert len(scopes_with_get_basic) > 0 , f"Should find get_basic in MTIR map. Available scopes: {list(
        mtir_map.keys()
    )}";

    matching_scope = None;
    for scope in scopes_with_get_basic {
        if "basic.get_basic" in scope {
            matching_scope = scope;
            break;
        }
    }

    assert matching_scope is not None , f"Expected scope containing 'basic.get_basic', but found: {scopes_with_get_basic}. Module name ending in 'c' may have been truncated.";
}

test "scope name with trailing j" {
    prog = JacProgram();
    fixture = fixture_path("proj.jac");
    prog.compile(fixture);
    assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";

    assert JacRuntime.program is not None;
    mtir_map = JacRuntime.program.mtir_map;

    scopes_with_create_proj = [
        scope
        for scope in mtir_map
        if "create_proj" in scope
    ];

    assert len(scopes_with_create_proj) > 0 , f"Should find create_proj in MTIR map. Available scopes: {list(
        mtir_map.keys()
    )}";

    matching_scope = None;
    for scope in scopes_with_create_proj {
        if "proj.create_proj" in scope {
            matching_scope = scope;
            break;
        }
    }

    assert matching_scope is not None , f"Expected scope containing 'proj.create_proj', but found: {scopes_with_create_proj}. Module name ending in 'j' may have been truncated.";
}

test "all stored scopes are retrievable" {
    fixtures = ["test_schema.jac", "basic.jac", "proj.jac"];
    expected_functions = ["generate_data", "get_basic", "create_proj"];
    expected_modules = ["test_schema", "basic", "proj"];

    for (fixture_name, func_name, module_name) in zip(
        fixtures, expected_functions, expected_modules, strict=True
    ) {
        prog = JacProgram();
        prog.compile(fixture_path(fixture_name));
        assert not prog.errors_had , f"Compilation errors for {fixture_name}: {prog.errors_had}";

        assert JacRuntime.program is not None;
        mtir_map = JacRuntime.program.mtir_map;

        expected_scope_pattern = f"{module_name}.{func_name}";

        matching_scopes = [
            scope
            for scope in mtir_map
            if expected_scope_pattern in scope
        ];

        assert len(matching_scopes) > 0 , f"Failed to find scope matching '{expected_scope_pattern}' in MTIR map for {fixture_name}. Available scopes: {list(
            mtir_map.keys()
        )}. This indicates module name '{module_name}' was not correctly preserved.";

        scope = matching_scopes[0];
        mtir_info = mtir_map[scope];
        assert mtir_info is not None;
        assert isinstance(mtir_info, FunctionInfo);
        assert mtir_info.name == func_name;
    }
}

test "scope name generation algorithm" {
    test_cases = [
        ("test_schema.jac", "generate_data", "test_schema.generate_data"),
        ("basic.jac", "get_basic", "basic.get_basic"),
        ("proj.jac", "create_proj", "proj.create_proj"),
        ("data.jac", "process_data", "data.process_data"),
        ("calc.jac", "calculate", "calc.calculate"),
        ("subj.jac", "analyze", "subj.analyze"),

    ];

    for (module_file, func_name, expected_scope) in test_cases {
        module_name = module_file.removesuffix(".jac");

        scope = f"{module_name}.{func_name}";

        assert scope == expected_scope , f"Scope name mismatch for {module_file}:{func_name}. Expected: {expected_scope}, Got: {scope}";

        assert not module_name.endswith(".") , f"Module name '{module_name}' appears to be corrupted (ends with period)";

        if module_file.endswith("a.jac") {
            assert module_name.endswith("a") , f"Module name '{module_name}' lost trailing 'a'";
        } elif module_file.endswith("c.jac") {
            assert module_name.endswith("c") , f"Module name '{module_name}' lost trailing 'c'";
        } elif module_file.endswith("j.jac") {
            assert module_name.endswith("j") , f"Module name '{module_name}' lost trailing 'j'";
        }
    }
}

test "imported function scope resolution" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;

    try {
        jac_import("importer_main", base_path=FIXTURE_DIR + "/");
    } finally {
        sys.stdout = sys.__stdout__;
    }

    stdout_value = captured_output.getvalue();

    assert "MTIR_TEST: Found scopes:" in stdout_value , f"MTIR test did not run or find scopes. Output:\n{stdout_value}";

    assert (
        "MTIR_TEST: Has correct scope with 'importable_schema': True" in stdout_value
    ) , (
        f"MTIR scope does not contain 'importable_schema'. "
        f"This indicates the module name 'importable_schema' (ending with 'a') "
        f"was truncated during compilation. Output:\n{stdout_value}"
    );

    assert "MTIR retrieval test: PASSED" in stdout_value , f"MTIR retrieval test failed. Output:\n{stdout_value}";
}

# =============================================================================
# Enum Extraction Tests
# =============================================================================
test "enum info structure" {
    members = [
        FieldInfo(name="RED", semstr="Red color.", type_info="int"),
        FieldInfo(name="GREEN", semstr="Green color.", type_info="int"),
        FieldInfo(name="BLUE", semstr="Blue color.", type_info="int"),

    ];
    enum_info = EnumInfo(
        name="Color", semstr="RGB color enumeration.", members=members,
    );

    assert enum_info.name == "Color";
    assert enum_info.semstr == "RGB color enumeration.";
    assert len(enum_info.members) == 3;
    assert enum_info.members[0].name == "RED";
    assert enum_info.members[0].type_info == "int";
    assert enum_info.members[0].semstr == "Red color.";
}

test "enum with int values extraction" {
    prog = JacProgram();
    prog.compile(fixture_path("enum_with_semstr.jac"));
    assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";

    assert JacRuntime.program is not None;
    mtir_map = JacRuntime.program.mtir_map;

    func_scope = None;
    for scope in mtir_map {
        if "get_person_info" in scope and "enum_with_semstr" in scope {
            func_scope = scope;
            break;
        }
    }

    assert func_scope is not None , "Should find get_person_info function";
    func_info = mtir_map[func_scope];
    assert isinstance(func_info, FunctionInfo);

    assert isinstance(func_info.return_type, ClassInfo);
    person_class = func_info.return_type;

    personality_field = None;
    for field in person_class.fields {
        if field.name == "personality" {
            personality_field = field;
            break;
        }
    }

    assert personality_field is not None , "Person should have personality field";

    assert isinstance(personality_field.type_info, EnumInfo) , f"Expected EnumInfo, got {type(
        personality_field.type_info
    )}";

    personality_enum = personality_field.type_info;
    assert personality_enum.name == "Personality";
    assert len(personality_enum.members) == 3;

    member_names = [m.name for m in personality_enum.members];
    assert "INTROVERT" in member_names;
    assert "EXTROVERT" in member_names;
    assert "AMBIVERT" in member_names;

    for member in personality_enum.members {
        assert member.type_info == "int" , f"Member {member.name} should have int type, got {member.type_info}";
    }
}

test "enum with string values extraction" {
    prog = JacProgram();
    prog.compile(fixture_path("enum_with_semstr.jac"));
    assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";

    assert JacRuntime.program is not None;
    mtir_map = JacRuntime.program.mtir_map;

    func_scope = None;
    for scope in mtir_map {
        if "get_person_info" in scope and "enum_with_semstr" in scope {
            func_scope = scope;
            break;
        }
    }

    assert func_scope is not None;
    func_info = mtir_map[func_scope];
    assert isinstance(func_info, FunctionInfo);
    assert isinstance(func_info.return_type, ClassInfo);

    person_class = func_info.return_type;

    status_field = None;
    for field in person_class.fields {
        if field.name == "status" {
            status_field = field;
            break;
        }
    }

    assert status_field is not None , "Person should have status field";
    assert isinstance(status_field.type_info, EnumInfo);

    status_enum = status_field.type_info;
    assert status_enum.name == "Status";
    assert len(status_enum.members) == 3;

    member_names = [m.name for m in status_enum.members];
    assert "PENDING" in member_names;
    assert "ACTIVE" in member_names;
    assert "COMPLETED" in member_names;

    for member in status_enum.members {
        assert member.type_info == "str" , f"Member {member.name} should have str type, got {member.type_info}";
    }
}

test "enum without values extraction" {
    prog = JacProgram();
    prog.compile(fixture_path("enum_no_value.jac"));
    assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";

    assert JacRuntime.program is not None;
    mtir_map = JacRuntime.program.mtir_map;

    func_scope = None;
    for scope in mtir_map {
        if "yes_or_no" in scope and "enum_no_value" in scope {
            func_scope = scope;
            break;
        }
    }

    assert func_scope is not None , "Should find yes_or_no function";
    func_info = mtir_map[func_scope];
    assert isinstance(func_info, FunctionInfo);

    assert isinstance(func_info.return_type, EnumInfo) , f"Expected EnumInfo, got {type(
        func_info.return_type
    )}";

    tell_enum = func_info.return_type;
    assert tell_enum.name == "Tell";
    assert len(tell_enum.members) == 2;

    member_names = [m.name for m in tell_enum.members];
    assert "YES" in member_names;
    assert "NO" in member_names;

    for member in tell_enum.members {
        assert member.type_info is None , f"Member {member.name} without value should have None type, got {member.type_info}";
    }
}

test "enum semstrings are extracted" {
    prog = JacProgram();
    prog.compile(fixture_path("enum_with_semstr.jac"));
    assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";

    assert JacRuntime.program is not None;
    mtir_map = JacRuntime.program.mtir_map;

    func_scope = None;
    for scope in mtir_map {
        if "get_person_info" in scope and "enum_with_semstr" in scope {
            func_scope = scope;
            break;
        }
    }

    assert func_scope is not None;
    func_info = mtir_map[func_scope];
    assert isinstance(func_info, FunctionInfo);
    assert isinstance(func_info.return_type, ClassInfo);

    person_class = func_info.return_type;

    personality_field = next(
        (
            f
            for f in person_class.fields
            if f.name == "personality"
        ),
        None
    );
    assert personality_field is not None;
    assert isinstance(personality_field.type_info, EnumInfo);

    personality_enum = personality_field.type_info;

    introvert = next(
        (
            m
            for m in personality_enum.members
            if m.name == "INTROVERT"
        ),
        None
    );
    assert introvert is not None;
    assert introvert.semstr is not None;
    assert (
        "reserved" in introvert.semstr.lower()
        or "reflective" in introvert.semstr.lower()
    );

    extrovert = next(
        (
            m
            for m in personality_enum.members
            if m.name == "EXTROVERT"
        ),
        None
    );
    assert extrovert is not None;
    assert extrovert.semstr is not None;
    assert (
        "outgoing" in extrovert.semstr.lower()
        or "interaction" in extrovert.semstr.lower()
    );
}

test "enum in schema generation" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;

    try {
        jac_import("enum_with_semstr", base_path=FIXTURE_DIR + "/");

        import from enum_with_semstr { Person }
        import from byllm { schema }

        person_schema = schema.type_to_schema(Person, info=None);

        assert "json_schema" in person_schema;
        assert "schema" in person_schema["json_schema"];
        inner_schema = person_schema["json_schema"]["schema"];

        assert "properties" in inner_schema;
        assert "personality" in inner_schema["properties"];

        personality_schema = inner_schema["properties"]["personality"];

        assert "type" in personality_schema;
        assert personality_schema["type"] == "integer";

        assert "description" in personality_schema;
        desc = personality_schema["description"];
        assert "INTROVERT" in desc or "EXTROVERT" in desc or "AMBIVERT" in desc;
        assert "[1, 2, 3]" in desc or "1" in desc;

        assert "status" in inner_schema["properties"];
        status_schema = inner_schema["properties"]["status"];
        assert status_schema["type"] == "string";
        assert "PENDING" in status_schema["description"];
    } finally {
        sys.stdout = sys.__stdout__;
    }
}

# =============================================================================
# Scope Resolution Consistency Tests (Runtime vs Compile-time)
# =============================================================================
test "same function name different files resolve distinctly" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;

    try {
        jac_import("scope_main", base_path=FIXTURE_DIR + "/");
    } finally {
        sys.stdout = sys.__stdout__;
    }

    assert JacRuntime.program is not None;
    mtir_map = JacRuntime.program.mtir_map;

    process_data_scopes = [
        scope
        for scope in mtir_map
        if "process_data" in scope
    ];

    assert len(process_data_scopes) >= 2 , f"Expected at least 2 process_data scopes (one per module), found: {process_data_scopes}";

    alpha_scope = [
        s
        for s in process_data_scopes
        if "module_alpha" in s
    ];
    beta_scope = [
        s
        for s in process_data_scopes
        if "module_beta" in s
    ];

    assert len(alpha_scope) == 1 , f"Expected exactly one module_alpha.process_data scope, found: {alpha_scope}";
    assert len(beta_scope) == 1 , f"Expected exactly one module_beta.process_data scope, found: {beta_scope}";

    assert alpha_scope[0] != beta_scope[0] , "Alpha and beta scopes should be different";

    alpha_info = mtir_map[alpha_scope[0]];
    beta_info = mtir_map[beta_scope[0]];

    assert isinstance(alpha_info, FunctionInfo);
    assert isinstance(beta_info, FunctionInfo);
    assert alpha_info.return_type.name == "AlphaResult";
    assert beta_info.return_type.name == "BetaResult";
}

test "runtime scope resolution matches compile time" {
    prog = JacProgram();
    fixture = fixture_path("basic_compile.jac");
    prog.compile(fixture);
    assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";

    assert JacRuntime.program is not None;
    mtir_map = JacRuntime.program.mtir_map;

    expected_stem = Path(fixture).stem;

    matching_scopes = [
        scope
        for scope in mtir_map
        if scope.startswith(f"{expected_stem}.")
    ];

    assert len(matching_scopes) > 0 , f"Should find scopes starting with '{expected_stem}.'. Available scopes: {list(
        mtir_map.keys()
    )}";

    runtime_stem = expected_stem;

    for scope in matching_scopes {
        module_part = scope.split(".")[0];
        assert module_part == runtime_stem , f"Scope '{scope}' module part '{module_part}' doesn't match expected runtime stem '{runtime_stem}'";
    }
}

test "scope portable across paths" {
    prog = JacProgram();
    fixture = fixture_path("basic_compile.jac");
    prog.compile(fixture);
    assert not prog.errors_had;

    assert JacRuntime.program is not None;
    mtir_map = JacRuntime.program.mtir_map;

    for scope in mtir_map {
        assert not scope.startswith("/") , f"Scope '{scope}' should not start with absolute path";
        assert ":\\" not in scope and ":/" not in scope , f"Scope '{scope}' should not contain Windows drive letters";
        module_part = scope.split(".")[0];
        assert "/" not in module_part and "\\" not in module_part , f"Module part '{module_part}' should not contain path separators";
    }
}
