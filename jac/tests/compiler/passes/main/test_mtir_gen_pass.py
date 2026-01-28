"""Test MTIR generation pass module."""

from collections.abc import Callable

from jaclang import JacRuntime as Jac
from jaclang.pycore.mtp import ClassInfo, FunctionInfo, MethodInfo
from jaclang.pycore.program import JacProgram


def test_mtir_gen_basic(fixture_path: Callable[[str], str]) -> None:
    """Test basic MTIR generation for GenAI abilities."""
    prog = JacProgram()
    prog.compile(fixture_path("mtir_gen.jac"))
    assert not prog.errors_had, f"Compilation errors: {prog.errors_had}"

    # MTIR is stored in JacRuntime.program.mtir_map
    assert Jac.program is not None
    mtir_map = Jac.program.mtir_map

    # Check that mtir_map has been populated
    assert mtir_map, "MTIR map should not be empty"

    # The MTIR pass should have captured the GenAI abilities
    # Scope format is: module.class.method or module.function
    scopes = list(mtir_map.keys())
    assert len(scopes) > 0, "Should have at least one MTIR entry"


def test_mtir_gen_standalone_function(fixture_path: Callable[[str], str]) -> None:
    """Test MTIR extraction for standalone GenAI functions."""
    prog = JacProgram()
    prog.compile(fixture_path("mtir_gen.jac"))
    assert not prog.errors_had

    assert Jac.program is not None
    mtir_map = Jac.program.mtir_map

    # Find the analyze_person function in mtir_map
    analyze_person_scope = None
    for scope in mtir_map:
        if "analyze_person" in scope:
            analyze_person_scope = scope
            break

    assert analyze_person_scope is not None, "analyze_person should be in mtir_map"

    func_info = mtir_map[analyze_person_scope]
    assert isinstance(func_info, FunctionInfo)
    assert func_info.name == "analyze_person"

    # Check parameters
    assert func_info.params is not None
    assert len(func_info.params) == 2
    param_names = [p.name for p in func_info.params]
    assert "person" in param_names
    assert "detail_level" in param_names

    # Check return type
    assert func_info.return_type == "str"


def test_mtir_gen_method(fixture_path: Callable[[str], str]) -> None:
    """Test MTIR extraction for class methods."""
    prog = JacProgram()
    prog.compile(fixture_path("mtir_gen.jac"))
    assert not prog.errors_had

    assert Jac.program is not None
    mtir_map = Jac.program.mtir_map

    # Find the Project.summarize method
    summarize_scope = None
    for scope in mtir_map:
        if "summarize" in scope:
            summarize_scope = scope
            break

    assert summarize_scope is not None, "Project.summarize should be in mtir_map"

    method_info = mtir_map[summarize_scope]
    assert isinstance(method_info, MethodInfo)
    assert method_info.name == "summarize"

    # Check parameters (should have 'query')
    assert method_info.params is not None
    param_names = [p.name for p in method_info.params]
    assert "query" in param_names

    # Method should have parent_class info
    assert method_info.parent_class is not None
    assert isinstance(method_info.parent_class, ClassInfo)
    assert method_info.parent_class.name == "Project"


def test_mtir_gen_complex_return_type(fixture_path: Callable[[str], str]) -> None:
    """Test MTIR extraction with complex return types."""
    prog = JacProgram()
    prog.compile(fixture_path("mtir_gen.jac"))
    assert not prog.errors_had

    assert Jac.program is not None
    mtir_map = Jac.program.mtir_map

    # Find the create_team function
    create_team_scope = None
    for scope in mtir_map:
        if "create_team" in scope:
            create_team_scope = scope
            break

    assert create_team_scope is not None, "create_team should be in mtir_map"

    func_info = mtir_map[create_team_scope]
    assert isinstance(func_info, FunctionInfo)

    # Return type should be ClassInfo for Team
    assert func_info.return_type is not None
    if isinstance(func_info.return_type, ClassInfo):
        assert func_info.return_type.name == "Team"
    elif isinstance(func_info.return_type, str):
        assert func_info.return_type == "Team"


def test_mtir_gen_list_return_type(fixture_path: Callable[[str], str]) -> None:
    """Test MTIR extraction with list return types."""
    prog = JacProgram()
    prog.compile(fixture_path("mtir_gen.jac"))
    assert not prog.errors_had

    assert Jac.program is not None
    mtir_map = Jac.program.mtir_map

    # Find the find_people function
    find_people_scope = None
    for scope in mtir_map:
        if "find_people" in scope:
            find_people_scope = scope
            break

    assert find_people_scope is not None, "find_people should be in mtir_map"

    func_info = mtir_map[find_people_scope]
    assert isinstance(func_info, FunctionInfo)

    # Return type should be a list type
    # The MTIR pass encodes list[T] as ("list", T)
    assert func_info.return_type is not None
    if isinstance(func_info.return_type, tuple):
        assert func_info.return_type[0] == "list"


def test_mtir_gen_semstrings(fixture_path: Callable[[str], str]) -> None:
    """Test that semstrings are captured in MTIR."""
    prog = JacProgram()
    prog.compile(fixture_path("mtir_gen.jac"))
    assert not prog.errors_had

    assert Jac.program is not None
    mtir_map = Jac.program.mtir_map

    # Find analyze_person which has semstrings defined
    analyze_person_scope = None
    for scope in mtir_map:
        if "analyze_person" in scope:
            analyze_person_scope = scope
            break

    assert analyze_person_scope is not None

    func_info = mtir_map[analyze_person_scope]
    assert isinstance(func_info, FunctionInfo)

    # The function should have a semstring
    assert func_info.semstr is not None
    assert "Analyze" in func_info.semstr

    # Parameters should also have semstrings
    assert func_info.params is not None
    person_param = next((p for p in func_info.params if p.name == "person"), None)
    if person_param and person_param.semstr:
        assert "person" in person_param.semstr.lower()


def test_mtir_gen_class_info_extraction(fixture_path: Callable[[str], str]) -> None:
    """Test that ClassInfo is properly extracted for parameter types."""
    prog = JacProgram()
    prog.compile(fixture_path("mtir_gen.jac"))
    assert not prog.errors_had

    assert Jac.program is not None
    mtir_map = Jac.program.mtir_map

    # Find analyze_person which takes a Person parameter
    analyze_person_scope = None
    for scope in mtir_map:
        if "analyze_person" in scope:
            analyze_person_scope = scope
            break

    assert analyze_person_scope is not None

    func_info = mtir_map[analyze_person_scope]
    assert isinstance(func_info, FunctionInfo)

    # Find the 'person' parameter
    assert func_info.params is not None
    person_param = next((p for p in func_info.params if p.name == "person"), None)
    assert person_param is not None

    # The type_info should be a ClassInfo for Person
    if isinstance(person_param.type_info, ClassInfo):
        assert person_param.type_info.name == "Person"
        # Check that Person's fields are captured
        field_names = [f.name for f in person_param.type_info.fields]
        assert "name" in field_names
        assert "age" in field_names


def test_mtir_gen_all_genai_abilities_captured(
    fixture_path: Callable[[str], str],
) -> None:
    """Test that all GenAI abilities in the fixture are captured."""
    prog = JacProgram()
    prog.compile(fixture_path("mtir_gen.jac"))
    assert not prog.errors_had

    assert Jac.program is not None
    mtir_map = Jac.program.mtir_map

    # We have 4 GenAI abilities in the fixture:
    # 1. Project.summarize (method)
    # 2. analyze_person (function)
    # 3. create_team (function)
    # 4. find_people (function)
    expected_abilities = ["summarize", "analyze_person", "create_team", "find_people"]

    found_abilities = set()
    for scope in mtir_map:
        for ability in expected_abilities:
            if ability in scope:
                found_abilities.add(ability)

    assert len(found_abilities) == len(expected_abilities), (
        f"Expected all GenAI abilities to be captured. "
        f"Found: {found_abilities}, Expected: {set(expected_abilities)}"
    )
