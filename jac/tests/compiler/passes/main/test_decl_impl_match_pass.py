"""Test pass module."""

import io
from collections.abc import Callable, Generator
from contextlib import AbstractContextManager
from pathlib import Path

import pytest

import jaclang.jac0core.unitree as uni
from jaclang import JacRuntime as Jac
from jaclang.cli.commands import execution  # type: ignore[attr-defined]
from jaclang.jac0core.program import JacProgram


@pytest.fixture(autouse=True)
def setup_jac_runtime(
    fixture_path: Callable[[str], str], fresh_jac_context: Path
) -> Generator[None, None, None]:
    """Set up and tear down Jac runtime for each test."""
    Jac.attach_program(JacProgram())
    yield


def test_parameter_count_mismatch(fixture_path: Callable[[str], str]) -> None:
    """Basic test for pass."""
    (out := JacProgram()).compile(fixture_path("defn_decl_mismatch.jac"))

    expected_stdout_values = (
        "Parameter count mismatch for ability impl.SomeObj.foo.",
        "    6 |",
        "    7 | # Miss match parameter count.",
        "    8 | impl SomeObj.foo(param1: str) -> str {",
        "      |      ^^^^^^^^^^^",
        '    9 |     return "foo";',
        "   10 | }",
        "From the declaration of foo.",
        "    1 | obj SomeObj {",
        "    2 |     def foo(param1: str, param2: int) -> str;",
        "      |         ^^^",
        "    3 |     def bar(param1: str, param2: int) -> str;",
        "    4 |     def baz -> str;",
        # Check for explicit self mismatch error
        "Parameter count mismatch for ability impl.SomeObj.baz.",
        "   17 | # Explicit self when decl has no params.",
        "   18 | impl SomeObj.baz(self: SomeObj) -> str {",
        "      |      ^^^^^^^^^^^",
        "From the declaration of baz.",
        "    4 |     def baz -> str;",
        "      |         ^^^",
    )

    errors_output = ""
    for error in out.errors_had:
        errors_output += error.pretty_print() + "\n"

    print(errors_output)
    for exp in expected_stdout_values:
        assert exp in errors_output


def test_ability_connected_to_decl(fixture_path: Callable[[str], str]) -> None:
    """Basic test for pass."""
    state = (out := JacProgram()).compile(fixture_path("base.jac"))
    assert not out.errors_had
    assert "impl.Test.say_hi" in state.impl_mod[0].sym_tab.names_in_scope
    say_hi_node = (
        state.impl_mod[0].sym_tab.names_in_scope["impl.Test.say_hi"].decl.name_of
    )
    assert isinstance(say_hi_node, uni.ImplDef) and say_hi_node.body is not None
    assert "impl.Test.init" in state.impl_mod[0].sym_tab.names_in_scope
    init_node = state.impl_mod[0].sym_tab.names_in_scope["impl.Test.init"].decl.name_of
    assert isinstance(init_node, uni.ImplDef) and init_node.body is not None


def test_ability_connected_to_decl_post(fixture_path: Callable[[str], str]) -> None:
    """Basic test for pass."""
    state = (out := JacProgram()).compile(fixture_path("base2.jac"))
    assert not out.errors_had
    assert "impl.Test.say_hi" in state.impl_mod[0].sym_tab.names_in_scope
    say_hi_node = (
        state.impl_mod[0].sym_tab.names_in_scope["impl.Test.say_hi"].decl.name_of
    )
    assert isinstance(say_hi_node, uni.ImplDef) and say_hi_node.body is not None
    assert "impl.Test.init" in state.impl_mod[0].sym_tab.names_in_scope
    init_node = state.impl_mod[0].sym_tab.names_in_scope["impl.Test.init"].decl.name_of
    assert isinstance(init_node, uni.ImplDef) and init_node.body is not None


def test_run_base2(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test that the walker and node can be created dynamically."""
    with capture_stdout() as captured_output:
        execution.run(fixture_path("base2.jac"))
    output = captured_output.getvalue().strip()
    assert "56" in output


def test_arch_ref_has_sym(fixture_path: Callable[[str], str]) -> None:
    """Basic test for pass."""
    state = JacProgram().compile(fixture_path("defs_and_uses.jac"))
    for i in state.get_all_sub_nodes(uni.ImplDef):
        assert i.sym is not None


def test_single_impl_annex(examples_path: Callable[[str], str]) -> None:
    """Basic test for pass."""
    mypass = JacProgram().compile(examples_path("manual_code/circle_pure.jac"))
    assert mypass.impl_mod[0].pp().count("ImplDef - impl.Circle.area") == 1


def test_impl_decl_resolution_fix(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test walking through edges and nodes."""
    with capture_stdout() as captured_output:
        Jac.jac_import("mtest", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert "2.0\n" in stdout_value


def test_impl_grab(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test walking through edges."""
    with capture_stdout() as captured_output:
        Jac.jac_import("impl_grab", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert "1.414" in stdout_value


def test_nested_impls(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Test complex nested impls."""
    with capture_stdout() as captured_output:
        Jac.jac_import("nested_impls", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue().split("\n")
    assert "Hello,from bar in kk" in stdout_value[0]
    assert "Greeting: Hello, World!" in stdout_value[1]
    assert "Repeated: Hello" in stdout_value[2]
    assert "Hello, World!" in stdout_value[3]
    assert "Last message:!" in stdout_value[4]
    assert "Final message:!" in stdout_value[5]


def test_abstraction_bug(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Parse micro jac file."""
    with capture_stdout() as captured_output:
        Jac.jac_import("atest", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert stdout_value == "42\n"


def test_inner_mod_impl(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Parse micro jac file."""
    with capture_stdout() as captured_output:
        Jac.jac_import("enumerations", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert stdout_value == "1\n"


def test_impl_body_symbol_resolution(fixture_path: Callable[[str], str]) -> None:
    """Test that symbols like 'self' and 'self.attr' are resolved in impl bodies.

    This tests the fix for symbol resolution in .impl.jac files, where symbols
    weren't being resolved because impl files are compiled before being linked
    to their base module.
    """
    state = (out := JacProgram()).compile(fixture_path("impl_symbol_resolution.jac"))
    assert not out.errors_had, f"Compilation errors: {out.errors_had}"

    # Find the impl module
    assert len(state.impl_mod) == 1, "Expected one impl module"
    impl_mod = state.impl_mod[0]

    # Get the ImplDef nodes
    impl_defs = [
        node
        for node in impl_mod.get_all_sub_nodes(uni.ImplDef)
        if isinstance(node, uni.ImplDef)
    ]
    assert len(impl_defs) == 2, f"Expected 2 ImplDef nodes, got {len(impl_defs)}"

    # Check that AtomTrailer chains (self.count, self.name) have their first
    # element (self) resolved. In Jac, 'self' is represented as SpecialVarRef.
    for impl_def in impl_defs:
        atom_trailers = impl_def.get_all_sub_nodes(uni.AtomTrailer)
        assert len(atom_trailers) > 0, (
            f"Expected AtomTrailer nodes in {impl_def.sym_name}"
        )

        for trailer in atom_trailers:
            chain = trailer.as_attr_list
            if chain and chain[0].sym_name == "self":
                assert chain[0].sym is not None, (
                    f"'self' in chain not resolved in {impl_def.sym_name}"
                )
                # Verify the symbol has the expected name
                assert chain[0].sym.sym_name == "self", (
                    f"Expected 'self' symbol, got {chain[0].sym.sym_name}"
                )
