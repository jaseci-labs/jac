"""Test for jaseci plugin."""

import io
import sys
from collections.abc import Callable, Generator
from pathlib import Path
from typing import TypedDict

import pytest

from jaclang import JacRuntime as Jac
from jaclang.cli.commands import execution  # type: ignore[attr-defined]
from tests.conftest import get_object
from tests.runtimelib.conftest import fixture_abs_path


class OutputCapturerDict(TypedDict):
    """Type for output_capturer fixture."""

    start: Callable[[], None]
    stop: Callable[[], None]
    get: Callable[[], str]


@pytest.fixture
def captured_output():
    """Fixture to capture stdout."""
    captured = io.StringIO()
    old_stdout = sys.stdout
    sys.stdout = captured
    yield captured
    sys.stdout = old_stdout


@pytest.fixture
def output_capturer() -> OutputCapturerDict:
    """Fixture that provides functions to capture and restore output."""
    captured: dict[str, object] = {"output": None, "old_stdout": sys.__stdout__}

    def start_capture() -> None:
        captured["output"] = io.StringIO()
        sys.stdout = captured["output"]  # type: ignore[assignment]

    def stop_capture() -> None:
        sys.stdout = captured["old_stdout"]  # type: ignore[assignment]

    def get_output() -> str:
        output = captured["output"]
        return output.getvalue() if output else ""  # type: ignore[attr-defined]

    return {"start": start_capture, "stop": stop_capture, "get": get_output}


@pytest.fixture
def jac_temp_dir(tmp_path: Path) -> Generator[Path, None, None]:
    """Fixture that provides a temp directory for Jac session files.

    Sets Jac.base_path_dir to the temp directory so session files
    are auto-generated there and cleaned up automatically by pytest.
    """
    original_base_path = Jac.base_path_dir
    Jac.set_base_path(str(tmp_path))
    yield tmp_path
    Jac.set_base_path(original_base_path)


def test_walker_simple_persistent(
    output_capturer: OutputCapturerDict,
    jac_temp_dir: Path,
) -> None:
    """Test simple persistent object."""
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("simple_persistent.jac"),
        entrypoint="create",
        args=[],
    )
    execution.enter(
        filename=fixture_abs_path("simple_persistent.jac"),
        entrypoint="traverse",
        args=[],
    )
    output = output_capturer["get"]().strip()
    assert output == "node a\nnode b"


def test_entrypoint_root(
    output_capturer: OutputCapturerDict,
    jac_temp_dir: Path,
) -> None:
    """Test entrypoint being root."""
    execution.enter(
        filename=fixture_abs_path("simple_persistent.jac"),
        entrypoint="create",
        args=[],
    )
    obj = get_object(
        filename=fixture_abs_path("simple_persistent.jac"),
        id="root",
    )
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("simple_persistent.jac"),
        entrypoint="traverse",
        args=[],
        node=str(obj["id"]),
    )
    output = output_capturer["get"]().strip()
    assert output == "node a\nnode b"


def test_entrypoint_non_root(
    output_capturer: OutputCapturerDict,
    jac_temp_dir: Path,
) -> None:
    """Test entrypoint being non root node."""
    execution.enter(
        filename=fixture_abs_path("simple_persistent.jac"),
        entrypoint="create",
        args=[],
    )
    obj = get_object(
        filename=fixture_abs_path("simple_persistent.jac"),
        id="root",
    )
    edge_obj = get_object(
        filename=fixture_abs_path("simple_persistent.jac"),
        id=obj["edges"][0].id.hex,
    )
    a_obj = get_object(
        filename=fixture_abs_path("simple_persistent.jac"),
        id=edge_obj["target"].id.hex,
    )
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("simple_persistent.jac"),
        entrypoint="traverse",
        node=str(a_obj["id"]),
        args=[],
    )
    output = output_capturer["get"]().strip()
    assert output == "node a\nnode b"


def test_get_edge(jac_temp_dir: Path) -> None:
    """Test get an edge object."""
    execution.run(
        filename=fixture_abs_path("simple_node_connection.jac"),
    )
    obj = get_object(
        filename=fixture_abs_path("simple_node_connection.jac"),
        id="root",
    )
    assert len(obj["edges"]) == 2
    edge_objs = [
        get_object(
            filename=fixture_abs_path("simple_node_connection.jac"),
            id=e.id.hex,
        )
        for e in obj["edges"]
    ]
    node_ids = [obj["target"].id.hex for obj in edge_objs]
    node_objs = [
        get_object(
            filename=fixture_abs_path("simple_node_connection.jac"),
            id=str(n_id),
        )
        for n_id in node_ids
    ]
    assert len(node_objs) == 2
    assert {obj["archetype"].tag for obj in node_objs} == {"first", "second"}


def test_filter_on_edge_get_edge(
    output_capturer: OutputCapturerDict,
    jac_temp_dir: Path,
) -> None:
    """Test filtering on edge."""
    execution.run(
        filename=fixture_abs_path("simple_node_connection.jac"),
    )
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("simple_node_connection.jac"),
        entrypoint="filter_on_edge_get_edge",
        args=[],
    )
    assert output_capturer["get"]().strip() == "[simple_edge(index=1)]"


def test_filter_on_edge_get_node(
    output_capturer: OutputCapturerDict,
    jac_temp_dir: Path,
) -> None:
    """Test filtering on edge, then get node."""
    execution.run(
        filename=fixture_abs_path("simple_node_connection.jac"),
    )
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("simple_node_connection.jac"),
        entrypoint="filter_on_edge_get_node",
        args=[],
    )
    assert output_capturer["get"]().strip() == "[simple(tag='second')]"


def test_filter_on_node_get_node(
    output_capturer: OutputCapturerDict,
    jac_temp_dir: Path,
) -> None:
    """Test filtering on node, then get edge."""
    execution.run(
        filename=fixture_abs_path("simple_node_connection.jac"),
    )
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("simple_node_connection.jac"),
        entrypoint="filter_on_node_get_node",
        args=[],
    )
    assert output_capturer["get"]().strip() == "[simple(tag='second')]"


def test_filter_on_edge_visit(
    output_capturer: OutputCapturerDict,
    jac_temp_dir: Path,
) -> None:
    """Test filtering on edge, then visit."""
    execution.run(
        filename=fixture_abs_path("simple_node_connection.jac"),
    )
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("simple_node_connection.jac"),
        entrypoint="filter_on_edge_visit",
        args=[],
    )
    assert output_capturer["get"]().strip() == "simple(tag='first')"


def test_filter_on_node_visit(
    output_capturer: OutputCapturerDict,
    jac_temp_dir: Path,
) -> None:
    """Test filtering on node, then visit."""
    execution.run(
        filename=fixture_abs_path("simple_node_connection.jac"),
    )
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("simple_node_connection.jac"),
        entrypoint="filter_on_node_visit",
        args=[],
    )
    assert output_capturer["get"]().strip() == "simple(tag='first')"


def test_indirect_reference_node(
    output_capturer: OutputCapturerDict,
    jac_temp_dir: Path,
) -> None:
    """Test reference node indirectly without visiting."""
    execution.enter(
        filename=fixture_abs_path("simple_persistent.jac"),
        entrypoint="create",
        args=[],
    )
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("simple_persistent.jac"),
        entrypoint="indirect_ref",
        args=[],
    )
    # FIXME: Figure out what to do with warning.
    # assert output_capturer["get"]().strip() == "[b(name='node b')]\n[GenericEdge()]"


def test_walker_purger(
    output_capturer: OutputCapturerDict,
    jac_temp_dir: Path,
) -> None:
    """Test simple persistent object."""
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("graph_purger.jac"),
        entrypoint="populate",
        args=[],
    )
    execution.enter(
        filename=fixture_abs_path("graph_purger.jac"),
        entrypoint="traverse",
        args=[],
    )
    execution.enter(
        filename=fixture_abs_path("graph_purger.jac"),
        entrypoint="check",
        args=[],
    )
    execution.enter(
        filename=fixture_abs_path("graph_purger.jac"),
        entrypoint="purge",
        args=[],
    )
    output = output_capturer["get"]().strip()
    assert output == (
        "Root()\n"
        "A(id=0)\nA(id=1)\n"
        "B(id=0)\nB(id=1)\nB(id=0)\nB(id=1)\n"
        "C(id=0)\nC(id=1)\nC(id=0)\nC(id=1)\nC(id=0)\nC(id=1)\nC(id=0)\nC(id=1)\n"
        "D(id=0)\nD(id=1)\nD(id=0)\nD(id=1)\nD(id=0)\nD(id=1)\nD(id=0)\nD(id=1)\n"
        "D(id=0)\nD(id=1)\nD(id=0)\nD(id=1)\nD(id=0)\nD(id=1)\nD(id=0)\nD(id=1)\n"
        "E(id=0)\nE(id=1)\nE(id=0)\nE(id=1)\nE(id=0)\nE(id=1)\nE(id=0)\nE(id=1)\n"
        "E(id=0)\nE(id=1)\nE(id=0)\nE(id=1)\nE(id=0)\nE(id=1)\nE(id=0)\nE(id=1)\n"
        "E(id=0)\nE(id=1)\nE(id=0)\nE(id=1)\nE(id=0)\nE(id=1)\nE(id=0)\nE(id=1)\n"
        "E(id=0)\nE(id=1)\nE(id=0)\nE(id=1)\nE(id=0)\nE(id=1)\nE(id=0)\nE(id=1)\n"
        "125\n124"
    )
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("graph_purger.jac"),
        entrypoint="traverse",
        args=[],
    )
    execution.enter(
        filename=fixture_abs_path("graph_purger.jac"),
        entrypoint="check",
        args=[],
    )
    execution.enter(
        filename=fixture_abs_path("graph_purger.jac"),
        entrypoint="purge",
        args=[],
    )
    output = output_capturer["get"]().strip()
    assert output == "Root()\n1\n0"


def trigger_access_validation_test(
    output_capturer: OutputCapturerDict,
    roots: list[str],
    nodes: list[str],
    give_access_to_full_graph: bool,
    via_all: bool = False,
) -> None:
    """Test different access validation."""
    output_capturer["start"]()

    ##############################################
    #              ALLOW READ ACCESS             #
    ##############################################

    node_1 = "" if give_access_to_full_graph else nodes[0]
    node_2 = "" if give_access_to_full_graph else nodes[1]

    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="allow_other_root_access",
        args=[roots[1], 0, via_all],
        root=roots[0],
        node=node_1,
    )
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="allow_other_root_access",
        args=[roots[0], 0, via_all],
        root=roots[1],
        node=node_2,
    )

    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="update_node",
        args=[20],
        root=roots[0],
        node=nodes[1],
    )
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="update_node",
        args=[10],
        root=roots[1],
        node=nodes[0],
    )

    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="update_target_node",
        args=[20, nodes[1]],
        root=roots[0],
    )

    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="update_target_node",
        args=[10, nodes[0]],
        root=roots[1],
    )

    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        root=roots[0],
        node=nodes[1],
    )
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        root=roots[1],
        node=nodes[0],
    )
    archs = output_capturer["get"]().strip().split("\n")
    assert len(archs) == 2

    # --------- NO UPDATE SHOULD HAPPEN -------- #

    assert archs[0] == "A(val=2)"
    assert archs[1] == "A(val=1)"

    # ---------- DISALLOW READ ACCESS ---------- #

    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="disallow_other_root_access",
        args=[roots[1], via_all],
        root=roots[0],
        node=node_1,
    )
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="disallow_other_root_access",
        args=[roots[0], via_all],
        root=roots[1],
        node=node_2,
    )

    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        root=roots[0],
        node=nodes[1],
    )
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        root=roots[1],
        node=nodes[0],
    )
    assert not output_capturer["get"]().strip()

    ##############################################
    #             ALLOW WRITE ACCESS             #
    ##############################################

    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="allow_other_root_access",
        args=[roots[1], "WRITE", via_all],
        root=roots[0],
        node=node_1,
    )
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="allow_other_root_access",
        args=[roots[0], "WRITE", via_all],
        root=roots[1],
        node=node_2,
    )

    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="update_node",
        args=[200],
        root=roots[0],
        node=nodes[1],
    )
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="update_node",
        args=[100],
        root=roots[1],
        node=nodes[0],
    )

    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        root=roots[0],
        node=nodes[1],
    )
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        root=roots[1],
        node=nodes[0],
    )
    archs = output_capturer["get"]().strip().split("\n")
    assert len(archs) == 2

    # ---------- UPDATE SHOULD HAPPEN ---------- #

    assert archs[0] == "A(val=200)"
    assert archs[1] == "A(val=100)"

    # ---------- DISALLOW WRITE ACCESS --------- #

    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="disallow_other_root_access",
        args=[roots[1], via_all],
        root=roots[0],
        node=node_1,
    )
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="disallow_other_root_access",
        args=[roots[0], via_all],
        root=roots[1],
        node=node_2,
    )

    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        root=roots[0],
        node=nodes[1],
    )
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        root=roots[1],
        node=nodes[0],
    )
    assert not output_capturer["get"]().strip()

    # ---------- ROOTS RESET OWN NODE ---------- #

    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="update_node",
        args=[1],
        root=roots[0],
        node=nodes[0],
    )
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="update_node",
        args=[2],
        root=roots[1],
        node=nodes[1],
    )


def test_other_root_access(
    output_capturer: OutputCapturerDict,
    jac_temp_dir: Path,
) -> None:
    """Test filtering on node, then visit."""
    ##############################################
    #                CREATE ROOTS                #
    ##############################################

    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="create_other_root",
        args=[],
    )
    root1 = output_capturer["get"]().strip()

    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="create_other_root",
        args=[],
    )
    root2 = output_capturer["get"]().strip()

    ##############################################
    #           CREATE RESPECTIVE NODES          #
    ##############################################

    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="create_node",
        args=[1],
        root=root1,
    )
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="create_node",
        args=[2],
        root=root2,
    )
    nodes = output_capturer["get"]().strip().split("\n")
    assert len(nodes) == 2

    ##############################################
    #           VISIT RESPECTIVE NODES           #
    ##############################################

    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        root=root1,
    )
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        root=root2,
    )
    archs = output_capturer["get"]().strip().split("\n")
    assert len(archs) == 2
    assert archs[0] == "A(val=1)"
    assert archs[1] == "A(val=2)"

    ##############################################
    #              SWAP TARGET NODE              #
    #                  NO ACCESS                 #
    ##############################################

    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        root=root1,
        node=nodes[1],
    )
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        root=root2,
        node=nodes[0],
    )
    assert not output_capturer["get"]().strip()

    ##############################################
    #        TEST DIFFERENT ACCESS OPTIONS       #
    ##############################################

    roots = [root1, root2]

    trigger_access_validation_test(
        output_capturer, roots, nodes, give_access_to_full_graph=False
    )
    trigger_access_validation_test(
        output_capturer, roots, nodes, give_access_to_full_graph=True
    )

    trigger_access_validation_test(
        output_capturer, roots, nodes, give_access_to_full_graph=False, via_all=True
    )
    trigger_access_validation_test(
        output_capturer, roots, nodes, give_access_to_full_graph=True, via_all=True
    )


def test_savable_object(
    output_capturer: OutputCapturerDict,
    jac_temp_dir: Path,
) -> None:
    """Test ObjectAnchor save."""
    output_capturer["start"]()

    execution.enter(
        filename=fixture_abs_path("savable_object.jac"),
        entrypoint="create_custom_object",
        args=[],
    )

    prints = output_capturer["get"]().strip().split("\n")
    id = prints[0]

    assert prints[1] == (
        "SavableObject(val=0, arr=[], json={}, parent=Parent(val=1, arr=[1], json"
        "={'a': 1}, enum_field=<Enum.B: 'b'>, child=Child(val=2, arr=[1, 2], json"
        "={'a': 1, 'b': 2}, enum_field=<Enum.C: 'c'>)), enum_field=<Enum.A: 'a'>)"
    )

    output_capturer["start"]()

    execution.enter(
        filename=fixture_abs_path("savable_object.jac"),
        entrypoint="get_custom_object",
        args=[id],
    )
    assert output_capturer["get"]().strip() == (
        "SavableObject(val=0, arr=[], json={}, parent=Parent(val=1, arr=[1], json"
        "={'a': 1}, enum_field=<Enum.B: 'b'>, child=Child(val=2, arr=[1, 2], json"
        "={'a': 1, 'b': 2}, enum_field=<Enum.C: 'c'>)), enum_field=<Enum.A: 'a'>)"
    )

    output_capturer["start"]()

    execution.enter(
        filename=fixture_abs_path("savable_object.jac"),
        entrypoint="update_custom_object",
        args=[id],
    )

    assert output_capturer["get"]().strip() == (
        "SavableObject(val=1, arr=[1], json={'a': 1}, parent=Parent(val=2, arr=[1, 2], json"
        "={'a': 1, 'b': 2}, enum_field=<Enum.C: 'c'>, child=Child(val=3, arr=[1, 2, 3], json"
        "={'a': 1, 'b': 2, 'c': 3}, enum_field=<Enum.A: 'a'>)), enum_field=<Enum.B: 'b'>)"
    )

    output_capturer["start"]()

    execution.enter(
        filename=fixture_abs_path("savable_object.jac"),
        entrypoint="delete_custom_object",
        args=[id],
    )

    execution.enter(
        filename=fixture_abs_path("savable_object.jac"),
        entrypoint="get_custom_object",
        args=[id],
    )
    assert output_capturer["get"]().strip() == "None"


def test_traversing_save(
    output_capturer: OutputCapturerDict,
    jac_temp_dir: Path,
) -> None:
    """Test traversing save."""
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("traversing_save.jac"),
        entrypoint="build",
        args=[],
    )

    execution.enter(
        filename=fixture_abs_path("traversing_save.jac"),
        entrypoint="view",
        args=[],
    )

    assert output_capturer["get"]().strip() == (
        "digraph {\n"
        'node [style="filled", shape="ellipse", fillcolor="invis", fontcolor="black"];\n'
        '0 -> 1  [label=""];\n'
        '1 -> 2  [label=""];\n'
        '0 [label="Root()"fillcolor="#FFE9E9"];\n'
        '1 [label="A()"fillcolor="#F0FFF0"];\n'
        '2 [label="B()"fillcolor="#F5E5FF"];\n}'
    )


def test_custom_access_validation(
    output_capturer: OutputCapturerDict,
    jac_temp_dir: Path,
) -> None:
    """Test custom access validation."""
    ##############################################
    #              CREATE OTHER ROOT             #
    ##############################################

    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("custom_access_validation.jac"),
        entrypoint="create_other_root",
        args=[],
    )

    other_root = output_capturer["get"]().strip()

    ##############################################
    #                 CREATE NODE                #
    ##############################################

    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("custom_access_validation.jac"),
        entrypoint="create",
        args=[],
    )
    node = output_capturer["get"]().strip()

    ##############################################
    #                 CHECK NODE                 #
    ##############################################

    # BY OWNER
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("custom_access_validation.jac"),
        entrypoint="check",
        args=[],
        node=node,
    )

    assert output_capturer["get"]().strip() == "A(val1='NO_ACCESS', val2=0)"

    # BY OTHER
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("custom_access_validation.jac"),
        entrypoint="check",
        args=[],
        root=other_root,
        node=node,
    )

    assert output_capturer["get"]().strip() == ""

    ##############################################
    #       UPDATE NODE (GIVE READ ACCESS)       #
    ##############################################

    # UPDATE BY OWNER
    execution.enter(
        filename=fixture_abs_path("custom_access_validation.jac"),
        entrypoint="update",
        args=["READ", None],
        node=node,
    )

    # CHECK BY OTHER
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("custom_access_validation.jac"),
        entrypoint="check",
        args=[],
        root=other_root,
        node=node,
    )

    assert output_capturer["get"]().strip() == "A(val1='READ', val2=0)"

    ##############################################
    #     UPDATE NODE (BUT STILL READ ACCESS)    #
    ##############################################

    # UPDATE BY OTHER
    execution.enter(
        filename=fixture_abs_path("custom_access_validation.jac"),
        entrypoint="update",
        args=[None, 1],
        root=other_root,
        node=node,
    )

    # CHECK BY OTHER
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("custom_access_validation.jac"),
        entrypoint="check",
        args=[],
        root=other_root,
        node=node,
    )

    assert output_capturer["get"]().strip() == "A(val1='READ', val2=0)"

    ##############################################
    #       UPDATE NODE (GIVE WRITE ACCESS)      #
    ##############################################

    # UPDATE BY OWNER
    execution.enter(
        filename=fixture_abs_path("custom_access_validation.jac"),
        entrypoint="update",
        args=["WRITE", None],
        node=node,
    )

    # UPDATE BY OTHER
    execution.enter(
        filename=fixture_abs_path("custom_access_validation.jac"),
        entrypoint="update",
        args=[None, 2],
        root=other_root,
        node=node,
    )

    # CHECK BY OTHER
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("custom_access_validation.jac"),
        entrypoint="check",
        args=[],
        root=other_root,
        node=node,
    )

    assert output_capturer["get"]().strip() == "A(val1='WRITE', val2=2)"

    ##############################################
    #         UPDATE NODE (REMOVE ACCESS)        #
    ##############################################

    # UPDATE BY OWNER
    execution.enter(
        filename=fixture_abs_path("custom_access_validation.jac"),
        entrypoint="update",
        args=["NO_ACCESS", None],
        node=node,
    )

    # UPDATE BY OTHER
    execution.enter(
        filename=fixture_abs_path("custom_access_validation.jac"),
        entrypoint="update",
        args=[None, 5],
        root=other_root,
        node=node,
    )

    # CHECK BY OTHER
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("custom_access_validation.jac"),
        entrypoint="check",
        args=[],
        root=other_root,
        node=node,
    )

    assert output_capturer["get"]().strip() == ""

    # CHECK BY OWNER
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("custom_access_validation.jac"),
        entrypoint="check",
        args=[],
        node=node,
    )

    assert output_capturer["get"]().strip() == "A(val1='NO_ACCESS', val2=2)"


def test_run_persistent_reuse(jac_temp_dir: Path) -> None:
    """Test that execution.run with session persists nodes to database."""
    import sqlite3
    from pickle import loads

    # Database path is auto-generated at jac_temp_dir/.jac/data/main.db
    db_path = jac_temp_dir / ".jac" / "data" / "main.db"

    ##############################################
    #          FIRST RUN - CREATE NODES          #
    ##############################################

    execution.run(
        filename=fixture_abs_path("simple_node_connection.jac"),
    )

    # Check database directly (not via get_object which re-runs code)
    conn = sqlite3.connect(str(db_path))
    cursor = conn.execute(
        "SELECT data FROM anchors WHERE id = ?",
        ("00000000-0000-0000-0000-000000000000",),
    )
    row = cursor.fetchone()
    assert row is not None, "Root should be persisted to database"
    root = loads(row[0])
    first_run_edges = len(root.edges)
    cursor = conn.execute("SELECT COUNT(*) FROM anchors")
    first_run_keys = cursor.fetchone()[0]
    conn.close()

    # Should have root + 2 nodes + 2 edges = 5 keys
    assert first_run_keys > 1, "First run should persist nodes to database"
    assert first_run_edges == 2, "Root should have 2 edges after first run"

    ##############################################
    #    SECOND RUN - SHOULD REUSE, NOT          #
    #              RECREATE NODES                #
    ##############################################

    execution.run(
        filename=fixture_abs_path("simple_node_connection.jac"),
    )

    # Check database again
    conn = sqlite3.connect(str(db_path))
    cursor = conn.execute(
        "SELECT data FROM anchors WHERE id = ?",
        ("00000000-0000-0000-0000-000000000000",),
    )
    row = cursor.fetchone()
    root = loads(row[0])
    second_run_edges = len(root.edges)
    cursor = conn.execute("SELECT COUNT(*) FROM anchors")
    second_run_keys = cursor.fetchone()[0]
    conn.close()

    # Should have same number of keys (not doubled)
    assert second_run_keys == first_run_keys, (
        "Second run should reuse persisted nodes, not create duplicates"
    )
    assert second_run_edges == 2, "Root should still have only 2 edges (not 4)"


def test_user_isolation_via_set_user_root(
    output_capturer: OutputCapturerDict,
    jac_temp_dir: Path,
) -> None:
    """Test that set_user_root properly isolates user data.

    This test verifies:
    1. Each user has their own root and sees only their own data
    2. Calling set_user_root (via execution.enter with root param) correctly
       sets the permission boundary for that user
    3. get_root() returns the correct user's root after context switch
    """
    # Create two separate user roots
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="create_other_root",
        args=[],
    )
    user1_root = output_capturer["get"]().strip()

    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="create_other_root",
        args=[],
    )
    user2_root = output_capturer["get"]().strip()

    # Verify different roots were created
    assert user1_root != user2_root, "Each user should have a unique root"

    # User 1 creates a node with val=100
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="create_node",
        args=[100],
        root=user1_root,
    )
    user1_node = output_capturer["get"]().strip()

    # User 2 creates a node with val=200
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="create_node",
        args=[200],
        root=user2_root,
    )
    user2_node = output_capturer["get"]().strip()

    # Verify user 1 can only see their own node (val=100)
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        root=user1_root,
    )
    user1_sees = output_capturer["get"]().strip()
    assert user1_sees == "A(val=100)", (
        f"User 1 should see their node, got: {user1_sees}"
    )

    # Verify user 2 can only see their own node (val=200)
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        root=user2_root,
    )
    user2_sees = output_capturer["get"]().strip()
    assert user2_sees == "A(val=200)", (
        f"User 2 should see their node, got: {user2_sees}"
    )

    # Verify user 1 cannot see user 2's node (cross-user isolation)
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        root=user1_root,
        node=user2_node,
    )
    cross_access = output_capturer["get"]().strip()
    assert cross_access == "", (
        f"User 1 should NOT see user 2's node, but got: {cross_access}"
    )

    # Verify user 2 cannot see user 1's node
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        root=user2_root,
        node=user1_node,
    )
    cross_access = output_capturer["get"]().strip()
    assert cross_access == "", (
        f"User 2 should NOT see user 1's node, but got: {cross_access}"
    )
