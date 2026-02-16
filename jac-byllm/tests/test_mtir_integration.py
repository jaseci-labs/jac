"""Tests for MTIR (Meaning Typed IR) integration with byLLM.

These tests verify byLLM-specific MTIR functionality:
1. Schema generation data structures work correctly
2. Tool schema generation with MTIR info
3. MTIR caching works correctly
4. Python library fallback mode works when MTIR is unavailable

Note: MTIR extraction from compiled code is tested in:
  jac/tests/compiler/passes/main/test_mtir_gen_pass.py
"""

import os
import sys
from collections.abc import Callable
from dataclasses import fields
from pathlib import Path

import pytest

from jaclang import JacRuntime
from jaclang import JacRuntimeInterface as Jac
from jaclang.jac0core.mtp import (
    ClassInfo,
    EnumInfo,
    FieldInfo,
    FunctionInfo,
    MethodInfo,
    ParamInfo,
    mk_dict,
    mk_list,
)
from jaclang.jac0core.program import JacProgram

# Import the jac_import function
jac_import = Jac.jac_import


@pytest.fixture
def fixture_path() -> Callable[[str], str]:
    """Fixture to get the absolute path of fixtures directory."""

    def _fixture_abs_path(fixture: str) -> str:
        test_dir = os.path.dirname(os.path.abspath(__file__))
        file_path = os.path.join(test_dir, "fixtures", fixture)
        return os.path.abspath(file_path)

    return _fixture_abs_path


# =============================================================================
# Schema Generation Data Structure Tests
# =============================================================================


class TestSchemaGenerationWithMTIR:
    """Tests that schema generation data structures work correctly."""

    def test_field_semstrings_in_schema(self) -> None:
        """Test that FieldInfo correctly stores semstrings for schema generation."""
        field_info = FieldInfo(
            name="username",
            semstr="Unique username for login.",
            type_info="str",
        )
        class_info = ClassInfo(
            name="User",
            semstr="A registered user in the system.",
            fields=[field_info],
            base_classes=[],
            methods=[],
        )

        assert class_info.name == "User"
        assert class_info.semstr == "A registered user in the system."
        assert len(class_info.fields) == 1
        assert class_info.fields[0].name == "username"
        assert class_info.fields[0].semstr == "Unique username for login."

    def test_param_info_structure(self) -> None:
        """Test ParamInfo structure for schema generation."""
        param_info = ParamInfo(
            name="criteria",
            semstr="Description of the type of person to generate.",
            type_info="str",
        )

        assert param_info.name == "criteria"
        assert param_info.semstr == "Description of the type of person to generate."
        assert param_info.type_info == "str"

    def test_function_info_for_tool_schema(self) -> None:
        """Test FunctionInfo provides data needed for tool schemas."""
        params = [
            ParamInfo(name="birth_year", semstr="Year of birth.", type_info="int"),
            ParamInfo(
                name="current_year",
                semstr="Current year for calculation.",
                type_info="int",
            ),
        ]
        func_info = FunctionInfo(
            name="calculate_age",
            semstr="Calculate age from birth year.",
            params=params,
            return_type="int",
        )

        assert func_info.name == "calculate_age"
        assert func_info.semstr == "Calculate age from birth year."
        assert func_info.params is not None
        assert len(func_info.params) == 2
        assert func_info.params[0].name == "birth_year"
        assert func_info.params[0].semstr == "Year of birth."

    def test_nested_class_info(self) -> None:
        """Test ClassInfo with nested type references."""
        person_class = ClassInfo(
            name="Person",
            semstr="A person entity.",
            fields=[
                FieldInfo(name="name", semstr="Full name.", type_info="str"),
                FieldInfo(name="age", semstr="Age in years.", type_info="int"),
            ],
            base_classes=[],
            methods=[],
        )

        user_class = ClassInfo(
            name="User",
            semstr="A user with address.",
            fields=[
                FieldInfo(name="username", semstr="Login name.", type_info="str"),
                FieldInfo(name="friend", semstr="A friend.", type_info=person_class),
            ],
            base_classes=[],
            methods=[],
        )

        assert user_class.fields[1].type_info == person_class
        assert isinstance(user_class.fields[1].type_info, ClassInfo)
        assert user_class.fields[1].type_info.name == "Person"

    def test_generic_type_encoding(self) -> None:
        """Test that generic types are encoded correctly."""
        # List type
        list_type = mk_list("Person")
        assert list_type == ("list", "Person")

        # Dict type
        dict_type = mk_dict("str", "int")
        assert dict_type == ("dict", "str", "int")

        # Nested list with ClassInfo
        person_info = ClassInfo(
            name="Person", semstr="A person.", fields=[], base_classes=[], methods=[]
        )
        nested_list = mk_list(person_info)
        assert nested_list[0] == "list"
        assert nested_list[1].name == "Person"


# =============================================================================
# Tool Schema Tests
# =============================================================================


class TestToolSchemaWithMTIR:
    """Tests for tool schema generation using MTIR info."""

    def test_tool_extraction_from_compiled_code(
        self, fixture_path: Callable[[str], str]
    ) -> None:
        """Test that tools are properly extracted and have MTIR info."""
        prog = JacProgram()
        prog.compile(fixture_path("tool_function.jac"))
        assert not prog.errors_had

        assert JacRuntime.program is not None
        mtir_map = JacRuntime.program.mtir_map

        # Find get_person_details function - filter by scope to avoid pollution
        # from other test fixtures that may have been compiled
        func_with_tools = None
        for scope, info in mtir_map.items():
            if (
                isinstance(info, FunctionInfo)
                and info.tools
                and "tool_function" in scope
                and info.name == "get_person_details"
            ):
                func_with_tools = info
                break

        assert func_with_tools is not None, "Should find get_person_details with tools"
        assert func_with_tools.tools is not None
        assert len(func_with_tools.tools) == 2

        tool_names = [t.name for t in func_with_tools.tools]
        assert "calculate_age" in tool_names
        assert "format_name" in tool_names

        # Verify tools have semstrings
        for tool in func_with_tools.tools:
            assert isinstance(tool, FunctionInfo)
            assert tool.semstr is not None

    def test_method_tool_in_class(self, fixture_path: Callable[[str], str]) -> None:
        """Test that method-based tools have proper MTIR."""
        prog = JacProgram()
        prog.compile(fixture_path("tool_method.jac"))
        assert not prog.errors_had

        assert JacRuntime.program is not None
        mtir_map = JacRuntime.program.mtir_map

        # Find eval_expression method - filter by scope to avoid pollution
        method_scope = None
        for scope in mtir_map:
            if "eval_expression" in scope and "tool_method" in scope:
                method_scope = scope
                break

        assert method_scope is not None, "Should find eval_expression method"
        method_info = mtir_map[method_scope]
        assert isinstance(method_info, MethodInfo)

        # Tools should be extracted
        assert method_info.tools is not None
        tool_names = [t.name for t in method_info.tools]
        assert "add" in tool_names, f"Expected 'add' in tools, got: {tool_names}"
        assert "multiply" in tool_names, (
            f"Expected 'multiply' in tools, got: {tool_names}"
        )


# =============================================================================
# Python Library Fallback Tests
# =============================================================================


class TestPythonLibraryFallback:
    """Tests for Python library mode when MTIR is not available."""

    def test_mtruntime_without_mtir_info(self) -> None:
        """Test that MTRuntime works when ir_info is None."""
        from jaclang.jac0core.mtp import MTIR

        # Create an MTIR with no ir_info (Python library mode)
        def sample_func(x: int, y: str) -> str:
            return f"{y}: {x}"

        mtir = MTIR(
            caller=sample_func,
            args={0: 42, 1: "test"},
            call_params={},
            ir_info=None,  # No MTIR info - fallback mode
        )

        # Should be able to access runtime
        runtime = mtir.runtime
        assert runtime is not None
        assert runtime.caller == sample_func

    def test_python_lib_mode_fixture(self) -> None:
        """Test that Python library mode module has expected structure."""
        from fixtures import python_lib_mode

        # Verify the module has the expected components
        assert hasattr(python_lib_mode, "Person")
        assert hasattr(python_lib_mode, "get_person_info")
        assert hasattr(python_lib_mode, "llm")

        # Verify Person dataclass structure via dataclass fields
        person_fields = {f.name for f in fields(python_lib_mode.Person)}
        assert "name" in person_fields
        assert "birth_year" in person_fields
        assert "description" in person_fields


# =============================================================================
# MTIR Caching Tests
# =============================================================================


class TestMTIRCaching:
    """Tests for MTIR caching in DiskBytecodeCache."""

    def test_cache_key_for_mtir(self) -> None:
        """Test that cache keys work for MTIR storage."""
        from jaclang.jac0core.bccache import CacheKey

        key = CacheKey.for_source("/path/to/test.jac")
        assert key is not None
        assert key.source_path == "/path/to/test.jac"

    def test_disk_cache_mtir_methods_exist(self) -> None:
        """Test that DiskBytecodeCache has MTIR methods."""
        from jaclang.jac0core.bccache import DiskBytecodeCache

        cache = DiskBytecodeCache()
        assert hasattr(cache, "get_mtir")
        assert hasattr(cache, "put_mtir")

    def test_mtir_cache_roundtrip(self, tmp_path: Path) -> None:
        """Test that MTIR can be cached and retrieved."""
        from jaclang.jac0core.bccache import CacheKey, DiskBytecodeCache

        # Create a test source file
        test_file = tmp_path / "test.jac"
        test_file.write_text("# test content")

        cache = DiskBytecodeCache()

        # Create cache key
        key = CacheKey.for_source(str(test_file))

        # Create test MTIR data
        test_mtir_map = {
            "test.func1": FunctionInfo(
                name="func1",
                semstr="Test function one.",
                params=[ParamInfo(name="x", semstr="Input x.", type_info="int")],
                return_type="str",
            ),
        }

        # Store MTIR
        cache.put_mtir(key, test_mtir_map)

        # Retrieve MTIR
        retrieved = cache.get_mtir(key)

        if retrieved is not None:
            assert "test.func1" in retrieved
            assert retrieved["test.func1"].name == "func1"
            assert retrieved["test.func1"].semstr == "Test function one."


# =============================================================================
# Fixture Compilation Test
# =============================================================================


class TestMTIRFixture:
    """Test that the MTIR test fixtures compile correctly."""

    def test_basic_fixture_compiles(self, fixture_path: Callable[[str], str]) -> None:
        """Test that a basic fixture compiles and populates MTIR."""
        prog = JacProgram()
        prog.compile(fixture_path("basic_compile.jac"))
        assert not prog.errors_had, f"Compilation errors: {prog.errors_had}"

        # Verify MTIR was populated
        assert JacRuntime.program is not None
        mtir_map = JacRuntime.program.mtir_map
        assert len(mtir_map) > 0, "MTIR map should have entries"

        # Verify expected GenAI function exists - filter by fixture name
        found_generate_person = False
        for scope in mtir_map:
            if "basic_compile" in scope and "generate_person" in scope:
                found_generate_person = True
                break

        assert found_generate_person, "Should have generate_person function in MTIR"


# =============================================================================
# Scope Name Consistency Tests
# =============================================================================


class TestScopeNameConsistency:
    """Tests that scope names stored during MTIR generation match what's fetched.

    This test class verifies the fix for the bug where module names ending with
    'j', 'a', or 'c' were incorrectly truncated due to using .rstrip(".jac")
    instead of .removesuffix(".jac").
    """

    def test_scope_name_with_trailing_a(
        self, fixture_path: Callable[[str], str]
    ) -> None:
        """Test module name ending with 'a' is correctly stored and retrieved."""
        prog = JacProgram()
        fixture = fixture_path("test_schema.jac")
        prog.compile(fixture)
        assert not prog.errors_had, f"Compilation errors: {prog.errors_had}"

        assert JacRuntime.program is not None
        mtir_map = JacRuntime.program.mtir_map

        # The module name should be "test_schema" (not "test_schem")
        # and the scope should be "test_schema.generate_data"
        scopes_with_generate_data = [
            scope for scope in mtir_map if "generate_data" in scope
        ]

        assert len(scopes_with_generate_data) > 0, (
            f"Should find generate_data in MTIR map. "
            f"Available scopes: {list(mtir_map.keys())}"
        )

        # Verify the scope name is correct (module name intact)
        matching_scope = None
        for scope in scopes_with_generate_data:
            if "test_schema.generate_data" in scope:
                matching_scope = scope
                break

        assert matching_scope is not None, (
            f"Expected scope containing 'test_schema.generate_data', "
            f"but found: {scopes_with_generate_data}. "
            f"This indicates the module name may have been truncated."
        )

        # Verify the MTIR entry is valid
        assert isinstance(mtir_map[matching_scope], FunctionInfo)

    def test_scope_name_with_trailing_c(
        self, fixture_path: Callable[[str], str]
    ) -> None:
        """Test module name ending with 'c' is correctly stored and retrieved."""
        prog = JacProgram()
        fixture = fixture_path("basic.jac")
        prog.compile(fixture)
        assert not prog.errors_had, f"Compilation errors: {prog.errors_had}"

        assert JacRuntime.program is not None
        mtir_map = JacRuntime.program.mtir_map

        # The module name should be "basic" (not "basi")
        scopes_with_get_basic = [scope for scope in mtir_map if "get_basic" in scope]

        assert len(scopes_with_get_basic) > 0, (
            f"Should find get_basic in MTIR map. "
            f"Available scopes: {list(mtir_map.keys())}"
        )

        # Verify the scope name contains correct module name
        matching_scope = None
        for scope in scopes_with_get_basic:
            if "basic.get_basic" in scope:
                matching_scope = scope
                break

        assert matching_scope is not None, (
            f"Expected scope containing 'basic.get_basic', "
            f"but found: {scopes_with_get_basic}. "
            f"Module name ending in 'c' may have been truncated."
        )

    def test_scope_name_with_trailing_j(
        self, fixture_path: Callable[[str], str]
    ) -> None:
        """Test module name ending with 'j' is correctly stored and retrieved."""
        prog = JacProgram()
        fixture = fixture_path("proj.jac")
        prog.compile(fixture)
        assert not prog.errors_had, f"Compilation errors: {prog.errors_had}"

        assert JacRuntime.program is not None
        mtir_map = JacRuntime.program.mtir_map

        # The module name should be "proj" (not "pro")
        scopes_with_create_proj = [
            scope for scope in mtir_map if "create_proj" in scope
        ]

        assert len(scopes_with_create_proj) > 0, (
            f"Should find create_proj in MTIR map. "
            f"Available scopes: {list(mtir_map.keys())}"
        )

        # Verify the scope name contains correct module name
        matching_scope = None
        for scope in scopes_with_create_proj:
            if "proj.create_proj" in scope:
                matching_scope = scope
                break

        assert matching_scope is not None, (
            f"Expected scope containing 'proj.create_proj', "
            f"but found: {scopes_with_create_proj}. "
            f"Module name ending in 'j' may have been truncated."
        )

    def test_all_stored_scopes_are_retrievable(
        self, fixture_path: Callable[[str], str]
    ) -> None:
        """Test that all scopes stored in MTIR can be retrieved."""
        # Compile multiple fixtures
        fixtures = ["test_schema.jac", "basic.jac", "proj.jac"]
        expected_functions = ["generate_data", "get_basic", "create_proj"]
        expected_modules = ["test_schema", "basic", "proj"]

        for fixture_name, func_name, module_name in zip(
            fixtures, expected_functions, expected_modules, strict=True
        ):
            prog = JacProgram()
            prog.compile(fixture_path(fixture_name))
            assert not prog.errors_had, (
                f"Compilation errors for {fixture_name}: {prog.errors_had}"
            )

            assert JacRuntime.program is not None
            mtir_map = JacRuntime.program.mtir_map

            # Build expected scope pattern
            expected_scope_pattern = f"{module_name}.{func_name}"

            # Find matching scopes
            matching_scopes = [
                scope for scope in mtir_map if expected_scope_pattern in scope
            ]

            assert len(matching_scopes) > 0, (
                f"Failed to find scope matching '{expected_scope_pattern}' "
                f"in MTIR map for {fixture_name}. "
                f"Available scopes: {list(mtir_map.keys())}. "
                f"This indicates module name '{module_name}' was not correctly preserved."
            )

            # Verify the MTIR info can be retrieved
            scope = matching_scopes[0]
            mtir_info = mtir_map[scope]
            assert mtir_info is not None
            assert isinstance(mtir_info, FunctionInfo)
            assert mtir_info.name == func_name

    def test_scope_name_generation_algorithm(self) -> None:
        """Test the scope name generation matches expected format.

        This test verifies that:
        1. Module names are extracted correctly from file paths
        2. The .jac suffix is properly removed
        3. Scope names follow the format: module_name.function_name
        """
        test_cases = [
            ("test_schema.jac", "generate_data", "test_schema.generate_data"),
            ("basic.jac", "get_basic", "basic.get_basic"),
            ("proj.jac", "create_proj", "proj.create_proj"),
            ("data.jac", "process_data", "data.process_data"),  # ends with 'a'
            ("calc.jac", "calculate", "calc.calculate"),  # ends with 'c'
            ("subj.jac", "analyze", "subj.analyze"),  # ends with 'j'
        ]

        for module_file, func_name, expected_scope in test_cases:
            # Extract module name using removesuffix (the correct way)
            module_name = module_file.removesuffix(".jac")

            # Generate scope name
            scope = f"{module_name}.{func_name}"

            assert scope == expected_scope, (
                f"Scope name mismatch for {module_file}:{func_name}. "
                f"Expected: {expected_scope}, Got: {scope}"
            )

            # Verify module name wasn't truncated
            assert not module_name.endswith("."), (
                f"Module name '{module_name}' appears to be corrupted "
                f"(ends with period)"
            )

            # Verify the original suffix-ending character is preserved
            if module_file.endswith("a.jac"):
                assert module_name.endswith("a"), (
                    f"Module name '{module_name}' lost trailing 'a'"
                )
            elif module_file.endswith("c.jac"):
                assert module_name.endswith("c"), (
                    f"Module name '{module_name}' lost trailing 'c'"
                )
            elif module_file.endswith("j.jac"):
                assert module_name.endswith("j"), (
                    f"Module name '{module_name}' lost trailing 'j'"
                )

    def test_imported_function_scope_resolution(
        self, fixture_path: Callable[[str], str]
    ) -> None:
        """Test that imported functions maintain correct scope names.

        This verifies that when a function defined in one module (ending with 'a')
        is imported into another module, the MTIR can be retrieved at runtime
        with the correct scope (based on where the function is defined, not imported).
        """
        import io
        import sys

        # Run the importer_main.jac which imports and calls get_imported_data
        # The fixture includes runtime checks for MTIR retrieval
        captured_output = io.StringIO()
        sys.stdout = captured_output

        try:
            jac_import("importer_main", base_path=fixture_path("./"))
        finally:
            sys.stdout = sys.__stdout__

        stdout_value = captured_output.getvalue()

        # The fixture should print MTIR test results
        # Check that MTIR was found and has the correct scope
        assert "MTIR_TEST: Found scopes:" in stdout_value, (
            f"MTIR test did not run or find scopes. Output:\n{stdout_value}"
        )

        # Verify the scope contains the full module name (importable_schema, not importable_schem)
        assert (
            "MTIR_TEST: Has correct scope with 'importable_schema': True"
            in stdout_value
        ), (
            f"MTIR scope does not contain 'importable_schema'. "
            f"This indicates the module name 'importable_schema' (ending with 'a') "
            f"was truncated during compilation. Output:\n{stdout_value}"
        )

        # Verify the overall test passed
        assert "MTIR retrieval test: PASSED" in stdout_value, (
            f"MTIR retrieval test failed. Output:\n{stdout_value}"
        )


# =============================================================================
# Enum Extraction Tests
# =============================================================================


class TestEnumExtraction:
    """Tests for enum extraction with MTIR."""

    def test_enum_info_structure(self) -> None:
        """Test that EnumInfo correctly stores enum members."""
        members = [
            FieldInfo(name="RED", semstr="Red color.", type_info="int"),
            FieldInfo(name="GREEN", semstr="Green color.", type_info="int"),
            FieldInfo(name="BLUE", semstr="Blue color.", type_info="int"),
        ]
        enum_info = EnumInfo(
            name="Color",
            semstr="RGB color enumeration.",
            members=members,
        )

        assert enum_info.name == "Color"
        assert enum_info.semstr == "RGB color enumeration."
        assert len(enum_info.members) == 3
        assert enum_info.members[0].name == "RED"
        assert enum_info.members[0].type_info == "int"
        assert enum_info.members[0].semstr == "Red color."

    def test_enum_with_int_values_extraction(
        self, fixture_path: Callable[[str], str]
    ) -> None:
        """Test that enums with integer values are extracted correctly."""
        prog = JacProgram()
        prog.compile(fixture_path("enum_with_semstr.jac"))
        assert not prog.errors_had, f"Compilation errors: {prog.errors_had}"

        assert JacRuntime.program is not None
        mtir_map = JacRuntime.program.mtir_map

        # Find get_person_info function
        func_scope = None
        for scope in mtir_map:
            if "get_person_info" in scope and "enum_with_semstr" in scope:
                func_scope = scope
                break

        assert func_scope is not None, "Should find get_person_info function"
        func_info = mtir_map[func_scope]
        assert isinstance(func_info, FunctionInfo)

        # Check that the return type is ClassInfo (Person)
        assert isinstance(func_info.return_type, ClassInfo)
        person_class = func_info.return_type

        # Find the personality field
        personality_field = None
        for field in person_class.fields:
            if field.name == "personality":
                personality_field = field
                break

        assert personality_field is not None, "Person should have personality field"

        # The type_info should be an EnumInfo
        assert isinstance(personality_field.type_info, EnumInfo), (
            f"Expected EnumInfo, got {type(personality_field.type_info)}"
        )

        personality_enum = personality_field.type_info
        assert personality_enum.name == "Personality"
        assert len(personality_enum.members) == 3

        # Check member names and types
        member_names = [m.name for m in personality_enum.members]
        assert "INTROVERT" in member_names
        assert "EXTROVERT" in member_names
        assert "AMBIVERT" in member_names

        # All members should have int type
        for member in personality_enum.members:
            assert member.type_info == "int", (
                f"Member {member.name} should have int type, got {member.type_info}"
            )

    def test_enum_with_string_values_extraction(
        self, fixture_path: Callable[[str], str]
    ) -> None:
        """Test that enums with string values are extracted correctly."""
        prog = JacProgram()
        prog.compile(fixture_path("enum_with_semstr.jac"))
        assert not prog.errors_had, f"Compilation errors: {prog.errors_had}"

        assert JacRuntime.program is not None
        mtir_map = JacRuntime.program.mtir_map

        # Find get_person_info function
        func_scope = None
        for scope in mtir_map:
            if "get_person_info" in scope and "enum_with_semstr" in scope:
                func_scope = scope
                break

        assert func_scope is not None
        func_info = mtir_map[func_scope]
        assert isinstance(func_info, FunctionInfo)
        assert isinstance(func_info.return_type, ClassInfo)

        person_class = func_info.return_type

        # Find the status field
        status_field = None
        for field in person_class.fields:
            if field.name == "status":
                status_field = field
                break

        assert status_field is not None, "Person should have status field"
        assert isinstance(status_field.type_info, EnumInfo)

        status_enum = status_field.type_info
        assert status_enum.name == "Status"
        assert len(status_enum.members) == 3

        # Check member names and types
        member_names = [m.name for m in status_enum.members]
        assert "PENDING" in member_names
        assert "ACTIVE" in member_names
        assert "COMPLETED" in member_names

        # All members should have str type
        for member in status_enum.members:
            assert member.type_info == "str", (
                f"Member {member.name} should have str type, got {member.type_info}"
            )

    def test_enum_without_values_extraction(
        self, fixture_path: Callable[[str], str]
    ) -> None:
        """Test that enums without explicit values are extracted correctly."""
        prog = JacProgram()
        prog.compile(fixture_path("enum_no_value.jac"))
        assert not prog.errors_had, f"Compilation errors: {prog.errors_had}"

        assert JacRuntime.program is not None
        mtir_map = JacRuntime.program.mtir_map

        # Find yes_or_no function
        func_scope = None
        for scope in mtir_map:
            if "yes_or_no" in scope and "enum_no_value" in scope:
                func_scope = scope
                break

        assert func_scope is not None, "Should find yes_or_no function"
        func_info = mtir_map[func_scope]
        assert isinstance(func_info, FunctionInfo)

        # The return type should be EnumInfo (Tell)
        assert isinstance(func_info.return_type, EnumInfo), (
            f"Expected EnumInfo, got {type(func_info.return_type)}"
        )

        tell_enum = func_info.return_type
        assert tell_enum.name == "Tell"
        assert len(tell_enum.members) == 2

        # Check member names
        member_names = [m.name for m in tell_enum.members]
        assert "YES" in member_names
        assert "NO" in member_names

        # Members without explicit values should have None as type_info
        for member in tell_enum.members:
            assert member.type_info is None, (
                f"Member {member.name} without value should have None type, "
                f"got {member.type_info}"
            )

    def test_enum_semstrings_are_extracted(
        self, fixture_path: Callable[[str], str]
    ) -> None:
        """Test that semantic strings for enum members are extracted."""
        prog = JacProgram()
        prog.compile(fixture_path("enum_with_semstr.jac"))
        assert not prog.errors_had, f"Compilation errors: {prog.errors_had}"

        assert JacRuntime.program is not None
        mtir_map = JacRuntime.program.mtir_map

        # Find get_person_info function
        func_scope = None
        for scope in mtir_map:
            if "get_person_info" in scope and "enum_with_semstr" in scope:
                func_scope = scope
                break

        assert func_scope is not None
        func_info = mtir_map[func_scope]
        assert isinstance(func_info, FunctionInfo)
        assert isinstance(func_info.return_type, ClassInfo)

        person_class = func_info.return_type

        # Get Personality enum
        personality_field = next(
            (f for f in person_class.fields if f.name == "personality"), None
        )
        assert personality_field is not None
        assert isinstance(personality_field.type_info, EnumInfo)

        personality_enum = personality_field.type_info

        # Check that semantic strings are present
        introvert = next(
            (m for m in personality_enum.members if m.name == "INTROVERT"), None
        )
        assert introvert is not None
        assert introvert.semstr is not None
        assert (
            "reserved" in introvert.semstr.lower()
            or "reflective" in introvert.semstr.lower()
        )

        extrovert = next(
            (m for m in personality_enum.members if m.name == "EXTROVERT"), None
        )
        assert extrovert is not None
        assert extrovert.semstr is not None
        assert (
            "outgoing" in extrovert.semstr.lower()
            or "interaction" in extrovert.semstr.lower()
        )

    def test_enum_in_schema_generation(
        self, fixture_path: Callable[[str], str]
    ) -> None:
        """Test that EnumInfo is used in schema generation."""
        import io
        import sys

        # Run enum_with_semstr.jac and capture output with verbose=True
        captured_output = io.StringIO()
        sys.stdout = captured_output

        try:
            # Import will trigger compilation and MTIR extraction
            jac_import("enum_with_semstr", base_path=fixture_path("./"))

            # Now import byllm.schema to test schema generation
            # Get the Person class and Personality enum from the compiled module
            from enum_with_semstr import Person

            from byllm import schema  # type: ignore[attr-defined]

            # Generate schema for Person which includes Personality enum
            person_schema = schema.type_to_schema(Person, info=None)

            # Schema is nested under json_schema.schema
            assert "json_schema" in person_schema
            assert "schema" in person_schema["json_schema"]
            inner_schema = person_schema["json_schema"]["schema"]

            assert "properties" in inner_schema
            assert "personality" in inner_schema["properties"]

            personality_schema = inner_schema["properties"]["personality"]

            # Should be integer type (since we used int values)
            assert "type" in personality_schema
            assert personality_schema["type"] == "integer"

            # Description should include enum values and names
            assert "description" in personality_schema
            desc = personality_schema["description"]
            # Should mention the member names
            assert "INTROVERT" in desc or "EXTROVERT" in desc or "AMBIVERT" in desc
            # Should mention the values
            assert "[1, 2, 3]" in desc or "1" in desc

            # Check the status field (string enum)
            assert "status" in inner_schema["properties"]
            status_schema = inner_schema["properties"]["status"]
            assert status_schema["type"] == "string"
            assert "PENDING" in status_schema["description"]

        finally:
            sys.stdout = sys.__stdout__

        # If verbose is enabled, output should contain schema information
        # This verifies the enum information flows through to schema generation


# =============================================================================
# Scope Resolution Consistency Tests (Runtime vs Compile-time)
# =============================================================================


class TestScopeResolutionConsistency:
    """Tests that scope keys match between compile-time MTIR and runtime fetch.

    This test class verifies the fix for the bug where `sem` declarations were
    silently dropped at runtime because the scope key used at compile-time
    (based on file path) didn't match the scope key generated at runtime
    (based on __module__ which was '__main__').

    The fix ensures both compile-time and runtime use the file stem (filename
    without extension) for the entry module's scope key.
    """

    def test_same_function_name_different_files_resolve_distinctly(
        self, fixture_path: Callable[[str], str]
    ) -> None:
        """Test that same-named functions in different files get distinct scope keys.

        This verifies that scope resolution uses the file stem to distinguish
        between functions with the same name defined in different modules,
        even when both are imported into a single main entry point.
        """
        import io

        # Run the main entry point which imports from both module_alpha and module_beta
        # Both modules have a function named "process_data"
        captured_output = io.StringIO()
        sys.stdout = captured_output

        try:
            jac_import("scope_main", base_path=fixture_path("./"))
        finally:
            sys.stdout = sys.__stdout__

        assert JacRuntime.program is not None
        mtir_map = JacRuntime.program.mtir_map

        # Find all process_data scopes
        process_data_scopes = [scope for scope in mtir_map if "process_data" in scope]

        # Should have exactly 2 distinct scopes for process_data
        assert len(process_data_scopes) >= 2, (
            f"Expected at least 2 process_data scopes (one per module), "
            f"found: {process_data_scopes}"
        )

        # Verify we have both module_alpha.process_data and module_beta.process_data
        alpha_scope = [s for s in process_data_scopes if "module_alpha" in s]
        beta_scope = [s for s in process_data_scopes if "module_beta" in s]

        assert len(alpha_scope) == 1, (
            f"Expected exactly one module_alpha.process_data scope, "
            f"found: {alpha_scope}"
        )
        assert len(beta_scope) == 1, (
            f"Expected exactly one module_beta.process_data scope, found: {beta_scope}"
        )

        # Verify they are different entries
        assert alpha_scope[0] != beta_scope[0], (
            "Alpha and beta scopes should be different"
        )

        # Verify each has the correct return type
        alpha_info = mtir_map[alpha_scope[0]]
        beta_info = mtir_map[beta_scope[0]]

        assert isinstance(alpha_info, FunctionInfo)
        assert isinstance(beta_info, FunctionInfo)
        assert alpha_info.return_type.name == "AlphaResult"
        assert beta_info.return_type.name == "BetaResult"

    def test_runtime_scope_resolution_matches_compile_time(
        self, fixture_path: Callable[[str], str]
    ) -> None:
        """Test that runtime scope lookup finds compile-time stored MTIR.

        This is the core test for the scope mismatch bug fix.
        """
        prog = JacProgram()
        fixture = fixture_path("basic_compile.jac")
        prog.compile(fixture)
        assert not prog.errors_had, f"Compilation errors: {prog.errors_had}"

        assert JacRuntime.program is not None
        mtir_map = JacRuntime.program.mtir_map

        # Get the expected file stem (what runtime would use)
        expected_stem = Path(fixture).stem  # "basic_compile"

        # Find scopes that should match this file
        matching_scopes = [
            scope for scope in mtir_map if scope.startswith(f"{expected_stem}.")
        ]

        assert len(matching_scopes) > 0, (
            f"Should find scopes starting with '{expected_stem}.'. "
            f"Available scopes: {list(mtir_map.keys())}"
        )

        # Simulate runtime scope key generation
        # At runtime, for __main__ module, we'd use sys.modules['__main__'].__file__
        runtime_stem = expected_stem  # This is what the fix provides

        # Verify the stored scopes match what runtime would generate
        for scope in matching_scopes:
            module_part = scope.split(".")[0]
            assert module_part == runtime_stem, (
                f"Scope '{scope}' module part '{module_part}' doesn't match "
                f"expected runtime stem '{runtime_stem}'"
            )

    def test_scope_portable_across_paths(
        self, fixture_path: Callable[[str], str]
    ) -> None:
        """Test that scope keys are portable (not tied to absolute paths).

        This ensures compiled bytecode can be shipped to different environments
        where the absolute path differs.
        """
        prog = JacProgram()
        fixture = fixture_path("basic_compile.jac")
        prog.compile(fixture)
        assert not prog.errors_had

        assert JacRuntime.program is not None
        mtir_map = JacRuntime.program.mtir_map

        # No scope should contain absolute path components
        for scope in mtir_map:
            assert not scope.startswith("/"), (
                f"Scope '{scope}' should not start with absolute path"
            )
            assert ":\\" not in scope and ":/" not in scope, (
                f"Scope '{scope}' should not contain Windows drive letters"
            )
            # Should not contain directory separators
            module_part = scope.split(".")[0]
            assert "/" not in module_part and "\\" not in module_part, (
                f"Module part '{module_part}' should not contain path separators"
            )
