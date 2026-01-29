"""Tests for Jac parser."""

import inspect
import io
import os
import re
import sys
from collections.abc import Callable
from pathlib import Path

import pytest

import jaclang
import jaclang.pycore.lark_jac_parser as jl
import jaclang.pycore.unitree as uni
from jaclang.pycore.constant import CodeContext, Tokens
from jaclang.pycore.jac_parser import JacParser
from jaclang.pycore.program import JacProgram
from jaclang.pycore.unitree import Source
from jaclang.runtimelib.utils import read_file_with_encoding
from tests.fixtures_list import MICRO_JAC_FILES


@pytest.fixture
def fixture_path() -> Callable[[str], str]:
    """Get absolute path to fixture file."""

    def _fixture_path(fixture: str) -> str:
        frame = inspect.currentframe()
        if frame is None or frame.f_back is None:
            raise ValueError("Unable to get the previous stack frame.")
        module = inspect.getmodule(frame.f_back)
        if module is None or module.__file__ is None:
            raise ValueError("Unable to determine the file of the module.")
        fixture_src = module.__file__
        file_path = os.path.join(os.path.dirname(fixture_src), "fixtures", fixture)
        return os.path.abspath(file_path)

    return _fixture_path


@pytest.fixture
def load_fixture() -> Callable[[str], str]:
    """Load fixture from fixtures directory."""

    def _load_fixture(fixture: str) -> str:
        frame = inspect.currentframe()
        if frame is None or frame.f_back is None:
            raise ValueError("Unable to get the previous stack frame.")
        module = inspect.getmodule(frame.f_back)
        if module is None or module.__file__ is None:
            raise ValueError("Unable to determine the file of the module.")
        fixture_src = module.__file__
        fixture_path = os.path.join(os.path.dirname(fixture_src), "fixtures", fixture)
        return read_file_with_encoding(fixture_path)

    return _load_fixture


@pytest.fixture
def file_to_str() -> Callable[[str], str]:
    """Load file to string."""

    def _file_to_str(file_path: str) -> str:
        return read_file_with_encoding(file_path)

    return _file_to_str


@pytest.fixture
def lang_fixture_abs_path() -> Callable[[str], str]:
    """Get language fixture absolute path."""
    from pathlib import Path

    def _lang_fixture_abs_path(file: str) -> str:
        # tests/compiler/test_parser.py -> tests/language/fixtures/
        tests_dir = Path(__file__).parent.parent
        file_path = tests_dir / "language" / "fixtures" / file
        return str(file_path.resolve())

    return _lang_fixture_abs_path


def test_fstring_escape_brace() -> None:
    """Test fstring escape brace."""
    source = Source('glob a=f"{{}}", not_b=4;', mod_path="")
    prse = JacParser(root_ir=source, prog=JacProgram())
    assert not prse.errors_had


def test_parser_fam(load_fixture: Callable[[str], str]) -> None:
    """Parse micro jac file."""
    prse = JacParser(
        root_ir=Source(load_fixture("fam.jac"), mod_path=""),
        prog=JacProgram(),
    )
    assert not prse.errors_had


def test_staticmethod_checks_out(load_fixture: Callable[[str], str]) -> None:
    """Parse micro jac file."""
    prse = JacParser(
        root_ir=Source(
            load_fixture("staticcheck.jac"),
            mod_path="",
        ),
        prog=JacProgram(),
    )
    out = prse.ir_out.pp()
    assert not prse.errors_had
    assert "staticmethod" not in out


def test_parser_kwesc(load_fixture: Callable[[str], str]) -> None:
    """Parse micro jac file."""
    prse = JacParser(
        root_ir=Source(load_fixture("kwesc.jac"), mod_path=""),
        prog=JacProgram(),
    )
    assert not prse.errors_had


def test_parser_mod_doc_test(load_fixture: Callable[[str], str]) -> None:
    """Parse micro jac file."""
    prse = JacParser(
        root_ir=Source(load_fixture("mod_doc_test.jac"), mod_path=""),
        prog=JacProgram(),
    )
    assert not prse.errors_had


def test_enum_matches_lark_toks() -> None:
    """Test that enum stays synced with lexer."""
    tokens = [x.name for x in jl.Lark_StandAlone().parser.lexer_conf.terminals]
    for token in tokens:
        assert token in Tokens.__members__
    for token in Tokens:
        assert token.name in tokens
    for token in Tokens:
        assert token.value in tokens


def test_parser_impl_all_rules() -> None:
    """Test that enum stays synced with lexer."""
    rules = {
        x.origin.name
        for x in jl.Lark_StandAlone().parser.parser_conf.rules
        if not x.origin.name.startswith("_")
    }
    parse_funcs = []
    for name, value in inspect.getmembers(JacParser.TreeToAST):
        if inspect.isfunction(value) and not getattr(
            JacParser.TreeToAST.__base__, value.__name__, False
        ):
            parse_funcs.append(name)
    for rule in rules:
        assert rule in parse_funcs
    for fn in parse_funcs:
        if fn.startswith("_") or fn in [
            "ice",
            "match",
            "consume",
            "match_token",
            "consume_token",
            "match_many",
            "consume_many",
            "extract_from_list",
        ]:
            continue
        assert fn in rules


def test_all_ast_has_normalize() -> None:
    """Test for enter/exit name diffs with parser."""
    import inspect
    import sys

    import jaclang.pycore.unitree as uni

    exclude = [
        "UniNode",
        "UniScopeNode",
        "UniCFGNode",
        "ContextAwareNode",
        "ProgramModule",
        "WalkerStmtOnlyNode",
        "Source",
        "EmptyToken",
        "AstSymbolNode",
        "AstSymbolStubNode",
        "AstImplNeedingNode",
        "AstAccessNode",
        "Literal",
        "AstDocNode",
        "AstSemStrNode",
        "PythonModuleAst",
        "AstAsyncNode",
        "AstElseBodyNode",
        "AstTypedVarNode",
        "AstImplOnlyNode",
        "Expr",
        "AtomExpr",
        "ElementStmt",
        "ArchBlockStmt",
        "EnumBlockStmt",
        "CodeBlockStmt",
        "NameAtom",
        "ArchSpec",
        "MatchPattern",
    ]
    module_name = uni.__name__
    module = sys.modules[module_name]

    # Retrieve the source code of the module
    source_code = inspect.getsource(module)

    classes = inspect.getmembers(module, inspect.isclass)
    uni_node_classes = [
        cls
        for _, cls in classes
        if issubclass(cls, uni.UniNode) and not issubclass(cls, uni.Token)
    ]

    ordered_classes = sorted(
        uni_node_classes,
        key=lambda cls: source_code.find(f"class {cls.__name__}"),
    )
    for cls in ordered_classes:
        if cls.__name__ not in exclude:
            assert "normalize" in cls.__dict__


def test_inner_mod_impl(fixture_path: Callable[[str], str]) -> None:
    """Parse micro jac file."""
    prog = JacProgram()
    prog.compile(fixture_path("codegentext.jac"))
    assert not prog.errors_had


def test_param_syntax(lang_fixture_abs_path: Callable[[str], str]) -> None:
    """Parse param syntax jac file."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    prog = JacProgram()
    prog.compile(lang_fixture_abs_path("params/param_syntax_err.jac"))
    sys.stdout = sys.__stdout__
    assert len(prog.errors_had) == 8


def test_new_keyword_errors(fixture_path: Callable[[str], str]) -> None:
    """Parse new keyword errors jac file."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    prog = JacProgram()
    prog.compile(fixture_path("new_keyword_errors.jac"))
    sys.stdout = sys.__stdout__
    assert len(prog.errors_had) == 4
    expected_substrings = [
        "The 'new' keyword is not supported in Jac",
        "Use `Reflect.construct(target, argumentsList)` method to create new instances",
        "The 'new' keyword is not supported in Jac",
        "Use `Reflect.construct(target, argumentsList)` method to create new instances",
    ]
    for alrt, expected in zip(prog.errors_had, expected_substrings, strict=True):
        pretty = alrt.pretty_print()
        assert expected in pretty


def test_pass_keyword_errors(fixture_path: Callable[[str], str]) -> None:
    """Parse pass keyword errors jac file."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    prog = JacProgram()
    prog.compile(fixture_path("pass_keyword_errors.jac"))
    sys.stdout = sys.__stdout__
    assert len(prog.errors_had) == 34
    expected_substrings = 17 * [
        "'pass' keyword is not allowed in Jac",
        "Jac does not allow this keyword in any syntactic position",
    ]
    for alrt, expected in zip(prog.errors_had, expected_substrings, strict=True):
        pretty = alrt.pretty_print()
        assert expected in pretty


def test_multiple_syntax_errors(fixture_path: Callable[[str], str]) -> None:
    """Parse multiple syntax errors jac file."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    prog = JacProgram()
    prog.compile(fixture_path("multiple_syntax_errors.jac"))
    sys.stdout = sys.__stdout__
    assert len(prog.errors_had) == 3
    expected_substrings = [
        "Missing RPAREN",
        "Missing COMMA",
        "Unexpected token",
    ]
    for alrt, expected in zip(prog.errors_had, expected_substrings, strict=True):
        pretty = alrt.pretty_print()
        assert expected in pretty


def _load_combined_jsx_fixture() -> tuple[str, JacParser]:
    """Parse the consolidated JSX fixture once for downstream assertions."""
    fixture_path = (
        Path(__file__).resolve().parent
        / "passes"
        / "ecmascript"
        / "fixtures"
        / "client_jsx.jac"
    )
    source_text = fixture_path.read_text(encoding="utf-8")
    prse = JacParser(
        root_ir=Source(source_text, mod_path=str(fixture_path)),
        prog=JacProgram(),
    )
    assert not prse.errors_had, (
        f"Parser reported errors for JSX fixture: {[str(e) for e in prse.errors_had]}"
    )
    return source_text, prse


def test_jsx_comprehensive_fixture() -> None:
    """Ensure the consolidated JSX fixture exercises varied grammar shapes."""
    source_text, prse = _load_combined_jsx_fixture()
    tree_repr = prse.ir_out.pp()

    expected_snippets = {
        "self_closing": "<div />",
        "attribute_binding": "id={name}",
        "namespaced_component": "<Form.Input.Text />",
        "fragment": "<>",
        "spread_attribute": "{...props}",
        "expression_child": '{"Hello " + name + "!"}',
    }
    for label, snippet in expected_snippets.items():
        assert snippet in source_text, f"{label}: {snippet} not found in source"

    ast_markers = {
        "JsxElement": "JsxElement" in tree_repr,
        "FragmentTokens": "Token - <>" in tree_repr and "Token - </>" in tree_repr,
        "JsxSpreadAttribute": "JsxSpreadAttribute" in tree_repr,
    }
    for label, present in ast_markers.items():
        assert present, f"{label} missing from AST pretty print"


def test_client_keyword_tagging() -> None:
    """Test that cl keyword properly tags elements as client declarations.

    Tests:
    - Single statement with cl prefix
    - Statement without cl prefix
    - Block of statements with cl { }
    - Empty cl blocks
    - Multiple cl blocks at top level
    - Various statement types (import, glob, obj, test)
    """
    # Test 1: Mixed single and block client markers
    source = """
cl glob foo = 1;
glob bar = 2;
cl {
    glob baz = 3;
    test sample {}
}
"""
    module = JacProgram().parse_str(source, "test.jac")
    body = module.body

    # With ClientBlock, cl {} creates a single ClientBlock node
    assert [type(stmt).__name__ for stmt in body] == [
        "GlobalVars",
        "GlobalVars",
        "ClientBlock",
    ]
    assert [
        isinstance(stmt, uni.ContextAwareNode)
        and stmt.code_context == CodeContext.CLIENT
        for stmt in body
    ] == [
        True,
        False,
        False,
    ]  # cl glob, glob, ClientBlock (not ContextAwareNode)
    # Check the ClientBlock's body
    client_block = body[2]
    assert isinstance(client_block, uni.ClientBlock)
    assert len(client_block.body) == 2
    assert [type(stmt).__name__ for stmt in client_block.body] == ["GlobalVars", "Test"]
    assert all(
        stmt.code_context == CodeContext.CLIENT
        for stmt in client_block.body
        if isinstance(stmt, uni.ContextAwareNode)
    )

    # Test 2: Block with different statement types
    source = """
cl {
    import foo;
    glob x = 1;
    obj MyClass {}
    test my_test {}
}
"""
    module = JacProgram().parse_str(source, "test.jac")
    body = module.body

    # With ClientBlock, all statements are wrapped in a single ClientBlock
    assert len(body) == 1
    assert isinstance(body[0], uni.ClientBlock)
    # Check the ClientBlock's body has 4 statements
    assert len(body[0].body) == 4
    assert all(
        stmt.code_context == CodeContext.CLIENT
        for stmt in body[0].body
        if isinstance(stmt, uni.ContextAwareNode)
    )

    # Test 3: Multiple cl blocks at top level
    source = """
cl {
    glob a = 1;
}
glob b = 2;
cl {
    glob c = 3;
}
"""
    module = JacProgram().parse_str(source, "test.jac")
    body = module.body

    # Now we have: ClientBlock, GlobalVars, ClientBlock
    assert len(body) == 3
    assert isinstance(body[0], uni.ClientBlock)
    assert isinstance(body[1], uni.GlobalVars)
    assert isinstance(body[2], uni.ClientBlock)
    assert not (
        isinstance(body[1], uni.ContextAwareNode)
        and body[1].code_context == CodeContext.CLIENT
    )  # glob b is not client

    # Test 4: Empty client block
    source = """
cl {}
glob x = 1;
"""
    module = JacProgram().parse_str(source, "test.jac")
    body = module.body

    # Empty ClientBlock followed by GlobalVars
    assert len(body) == 2
    assert isinstance(body[0], uni.ClientBlock)
    assert len(body[0].body) == 0  # Empty
    assert isinstance(body[1], uni.GlobalVars)
    assert not (
        isinstance(body[1], uni.ContextAwareNode)
        and body[1].code_context == CodeContext.CLIENT
    )

    # Test 5: Various statement types with single cl marker
    source = """
cl import foo;
cl obj MyClass {}
cl test my_test {}
"""
    module = JacProgram().parse_str(source, "test.jac")
    body = module.body

    assert len(body) == 3
    assert all(
        stmt.code_context == CodeContext.CLIENT
        for stmt in body
        if isinstance(stmt, uni.ContextAwareNode)
    )


def test_anonymous_ability_decl() -> None:
    """Test that abilities can be declared without explicit names.

    Tests:
    - Anonymous ability with entry event
    - Anonymous ability with exit event
    - Named ability still works
    - Autogenerated names are unique based on location
    """
    # Test 1: Anonymous ability with entry event
    source = """
walker MyWalker {
    can with entry {
        print("hello");
    }
}
"""
    prog = JacProgram()
    module = prog.parse_str(source, "test.jac")
    assert not prog.errors_had

    # Find the walker and its ability
    walker = module.body[0]
    assert isinstance(walker, uni.Archetype)
    assert walker.body is not None
    abilities = [stmt for stmt in walker.body if type(stmt).__name__ == "Ability"]
    assert len(abilities) == 1

    ability = abilities[0]
    assert isinstance(ability, uni.Ability)
    assert ability.name_ref is not None
    # Check that py_resolve_name generates a name
    resolved_name = ability.py_resolve_name()
    assert resolved_name.startswith("__ability_entry_")
    assert resolved_name.endswith("__")

    # Test 2: Anonymous ability with exit event
    source = """
walker MyWalker {
    can with exit {
        print("goodbye");
    }
}
"""
    prog = JacProgram()
    module = prog.parse_str(source, "test.jac")
    assert not prog.errors_had

    walker = module.body[0]
    assert isinstance(walker, uni.Archetype)
    assert walker.body is not None
    abilities = [stmt for stmt in walker.body if type(stmt).__name__ == "Ability"]
    ability = abilities[0]
    assert isinstance(ability, uni.Ability)
    resolved_name = ability.py_resolve_name()
    assert resolved_name.startswith("__ability_exit_")

    # Test 3: Named ability still works
    source = """
walker MyWalker {
    can my_ability with entry {
        print("named");
    }
}
"""
    prog = JacProgram()
    module = prog.parse_str(source, "test.jac")
    assert not prog.errors_had

    walker = module.body[0]
    assert isinstance(walker, uni.Archetype)
    assert walker.body is not None
    abilities = [stmt for stmt in walker.body if type(stmt).__name__ == "Ability"]
    ability = abilities[0]
    assert isinstance(ability, uni.Ability)
    assert ability.name_ref is not None
    assert ability.py_resolve_name() == "my_ability"

    # Test 4: Multiple anonymous abilities generate unique names
    source = """
walker MyWalker {
    can with entry {
        print("first");
    }
    can with entry {
        print("second");
    }
}
"""
    prog = JacProgram()
    module = prog.parse_str(source, "test.jac")
    assert not prog.errors_had

    walker = module.body[0]
    assert isinstance(walker, uni.Archetype)
    assert walker.body is not None
    abilities = [stmt for stmt in walker.body if type(stmt).__name__ == "Ability"]
    assert len(abilities) == 2

    ability0 = abilities[0]
    ability1 = abilities[1]
    assert isinstance(ability0, uni.Ability)
    assert isinstance(ability1, uni.Ability)
    name1 = ability0.py_resolve_name()
    name2 = ability1.py_resolve_name()
    # Names should be different due to different locations
    assert name1 != name2


def test_cl_import_with_jac_runtime() -> None:
    """Test that cl import with @jac/runtime path is properly parsed.

    Tests:
    - cl import from "@jac/runtime" syntax
    - Import is marked as client-side
    - String path is properly captured
    """
    source = """
cl import from "@jac/runtime" {
    jacLogin,
    jacLogout,
    renderJsxTree,
}
"""
    prog = JacProgram()
    module = prog.parse_str(source, "test.jac")
    assert not prog.errors_had, f"Parser errors: {prog.errors_had}"

    # Find the import statement
    imports = [stmt for stmt in module.body if type(stmt).__name__ == "Import"]
    assert len(imports) == 1, "Should have one import statement"

    import_stmt = imports[0]
    assert isinstance(import_stmt, uni.Import)

    # Check that it's a client import
    assert import_stmt.code_context == CodeContext.CLIENT, (
        "Import should be marked as client-side"
    )

    # Check the from_loc path
    assert import_stmt.from_loc is not None, "Import should have from_loc"

    # Check the module path (string literal)
    assert import_stmt.from_loc.dot_path_str == "@jac/runtime", (
        "Module path should be '@jac/runtime'"
    )

    # Check the imported items
    assert len(import_stmt.items) == 3, "Should have 3 imported items"
    item_names = [
        item.name.value
        for item in import_stmt.items
        if isinstance(item, uni.ModuleItem)
    ]
    assert "jacLogin" in item_names
    assert "jacLogout" in item_names
    assert "renderJsxTree" in item_names


# Micro suite test generation
def _micro_suite_test(filename: str, file_to_str: Callable[[str], str]) -> None:
    """Parse micro jac file."""
    prse = JacParser(
        root_ir=Source(file_to_str(filename), mod_path=filename),
        prog=JacProgram(),
    )
    # A list of files where the errors are expected.
    files_expected_errors = [
        "uninitialized_hasvars.jac",
    ]
    if os.path.basename(filename) not in files_expected_errors:
        assert not prse.errors_had


# Dynamically generate micro suite tests


def _sanitize_test_name(name: str) -> str:
    """Sanitize test name to be a valid Python identifier."""
    # Replace .jac extension first
    name = name.replace(".jac", "")
    # Replace path separators
    name = name.replace(os.sep, "_")
    # Replace any non-alphanumeric characters with underscores
    name = re.sub(r"[^a-zA-Z0-9_]", "_", name)
    # Ensure it doesn't start with a digit
    if name and name[0].isdigit():
        name = "_" + name
    return name


# Use fixed file list for deterministic test discovery
# To add new test files, update MICRO_JAC_FILES in tests/fixtures_list.py
_base_dir = os.path.dirname(os.path.dirname(jaclang.__file__))
for filename in [os.path.normpath(os.path.join(_base_dir, f)) for f in MICRO_JAC_FILES]:
    test_name = f"test_micro_{_sanitize_test_name(filename)}"
    # Create the test function dynamically
    exec(f"""
def {test_name}(file_to_str):
    _micro_suite_test({repr(filename)}, file_to_str)
""")
