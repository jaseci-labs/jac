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
from collections.abc import Callable
from dataclasses import fields
from pathlib import Path

import pytest

from jaclang import JacRuntime
from jaclang import JacRuntimeInterface as Jac
from jaclang.pycore.mtp import (
    ClassInfo,
    FieldInfo,
    FunctionInfo,
    MethodInfo,
    ParamInfo,
    mk_dict,
    mk_list,
)
from jaclang.pycore.program import JacProgram

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
        from jaclang.pycore.mtp import MTIR

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
        from jaclang.pycore.bccache import CacheKey

        key = CacheKey.for_source("/path/to/test.jac", minimal=False)
        assert key is not None
        assert key.source_path == "/path/to/test.jac"

    def test_disk_cache_mtir_methods_exist(self) -> None:
        """Test that DiskBytecodeCache has MTIR methods."""
        from jaclang.pycore.bccache import DiskBytecodeCache

        cache = DiskBytecodeCache()
        assert hasattr(cache, "get_mtir")
        assert hasattr(cache, "put_mtir")

    def test_mtir_cache_roundtrip(self, tmp_path: Path) -> None:
        """Test that MTIR can be cached and retrieved."""
        from jaclang.pycore.bccache import CacheKey, DiskBytecodeCache

        # Create a test source file
        test_file = tmp_path / "test.jac"
        test_file.write_text("# test content")

        cache = DiskBytecodeCache()

        # Create cache key
        key = CacheKey.for_source(str(test_file), minimal=False)

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
