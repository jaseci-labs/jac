"""Test for jaseci plugin."""

import io
import os
import sys
from collections.abc import Callable
from typing import TypedDict

import pytest

from jaclang.cli.commands import execution  # type: ignore[attr-defined]
from tests.conftest import get_object
from tests.runtimelib.conftest import fixture_abs_path


class OutputCapturerDict(TypedDict):
    """Type for output_capturer fixture."""

    start: Callable[[], None]
    stop: Callable[[], None]
    get: Callable[[], str]


session = ""


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


def del_session(session: str) -> None:
    """Delete session files."""
    path = os.path.dirname(session)
    prefix = os.path.basename(session)
    for file in os.listdir(path):
        if file.startswith(prefix):
            os.remove(f"{path}/{file}")


def test_walker_simple_persistent(
    output_capturer: OutputCapturerDict,
) -> None:
    """Test simple persistent object."""
    session = fixture_abs_path("test_walker_simple_persistent.session")
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("simple_persistent.jac"),
        session=session,
        entrypoint="create",
        args=[],
    )
    execution.enter(
        filename=fixture_abs_path("simple_persistent.jac"),
        session=session,
        entrypoint="traverse",
        args=[],
    )
    output = output_capturer["get"]().strip()
    assert output == "node a\nnode b"
    del_session(session)


def test_entrypoint_root(
    output_capturer: OutputCapturerDict,
) -> None:
    """Test entrypoint being root."""
    session = fixture_abs_path("test_entrypoint_root.session")
    execution.enter(
        filename=fixture_abs_path("simple_persistent.jac"),
        session=session,
        entrypoint="create",
        args=[],
    )
    obj = get_object(
        filename=fixture_abs_path("simple_persistent.jac"),
        id="root",
        session=session,
    )
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("simple_persistent.jac"),
        session=session,
        entrypoint="traverse",
        args=[],
        node=str(obj["id"]),
    )
    output = output_capturer["get"]().strip()
    assert output == "node a\nnode b"
    del_session(session)


def test_entrypoint_non_root(
    output_capturer: OutputCapturerDict,
) -> None:
    """Test entrypoint being non root node."""
    session = fixture_abs_path("test_entrypoint_non_root.session")
    execution.enter(
        filename=fixture_abs_path("simple_persistent.jac"),
        session=session,
        entrypoint="create",
        args=[],
    )
    obj = get_object(
        filename=fixture_abs_path("simple_persistent.jac"),
        id="root",
        session=session,
    )
    edge_obj = get_object(
        filename=fixture_abs_path("simple_persistent.jac"),
        id=obj["edges"][0].id.hex,
        session=session,
    )
    a_obj = get_object(
        filename=fixture_abs_path("simple_persistent.jac"),
        id=edge_obj["target"].id.hex,
        session=session,
    )
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("simple_persistent.jac"),
        session=session,
        entrypoint="traverse",
        node=str(a_obj["id"]),
        args=[],
    )
    output = output_capturer["get"]().strip()
    del_session(session)
    assert output == "node a\nnode b"


def test_get_edge():
    """Test get an edge object."""
    session = fixture_abs_path("test_get_edge.session")
    execution.run(
        filename=fixture_abs_path("simple_node_connection.jac"),
        session=session,
    )
    obj = get_object(
        filename=fixture_abs_path("simple_node_connection.jac"),
        session=session,
        id="root",
    )
    assert len(obj["edges"]) == 2
    edge_objs = [
        get_object(
            filename=fixture_abs_path("simple_node_connection.jac"),
            session=session,
            id=e.id.hex,
        )
        for e in obj["edges"]
    ]
    node_ids = [obj["target"].id.hex for obj in edge_objs]
    node_objs = [
        get_object(
            filename=fixture_abs_path("simple_node_connection.jac"),
            session=session,
            id=str(n_id),
        )
        for n_id in node_ids
    ]
    assert len(node_objs) == 2
    assert {obj["archetype"].tag for obj in node_objs} == {"first", "second"}
    del_session(session)


def test_filter_on_edge_get_edge(
    output_capturer: OutputCapturerDict,
) -> None:
    """Test filtering on edge."""
    session = fixture_abs_path("test_filter_on_edge_get_edge.session")
    execution.run(
        filename=fixture_abs_path("simple_node_connection.jac"),
        session=session,
    )
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("simple_node_connection.jac"),
        session=session,
        entrypoint="filter_on_edge_get_edge",
        args=[],
    )
    assert output_capturer["get"]().strip() == "[simple_edge(index=1)]"
    del_session(session)


def test_filter_on_edge_get_node(
    output_capturer: OutputCapturerDict,
) -> None:
    """Test filtering on edge, then get node."""
    session = fixture_abs_path("test_filter_on_edge_get_node.session")
    execution.run(
        filename=fixture_abs_path("simple_node_connection.jac"),
        session=session,
    )
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("simple_node_connection.jac"),
        session=session,
        entrypoint="filter_on_edge_get_node",
        args=[],
    )
    assert output_capturer["get"]().strip() == "[simple(tag='second')]"
    del_session(session)


def test_filter_on_node_get_node(
    output_capturer: OutputCapturerDict,
) -> None:
    """Test filtering on node, then get edge."""
    session = fixture_abs_path("test_filter_on_node_get_node.session")
    execution.run(
        filename=fixture_abs_path("simple_node_connection.jac"),
        session=session,
    )
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("simple_node_connection.jac"),
        session=session,
        entrypoint="filter_on_node_get_node",
        args=[],
    )
    assert output_capturer["get"]().strip() == "[simple(tag='second')]"
    del_session(session)


def test_filter_on_edge_visit(
    output_capturer: OutputCapturerDict,
) -> None:
    """Test filtering on edge, then visit."""
    session = fixture_abs_path("test_filter_on_edge_visit.session")
    execution.run(
        filename=fixture_abs_path("simple_node_connection.jac"),
        session=session,
    )
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("simple_node_connection.jac"),
        session=session,
        entrypoint="filter_on_edge_visit",
        args=[],
    )
    assert output_capturer["get"]().strip() == "simple(tag='first')"
    del_session(session)


def test_filter_on_node_visit(
    output_capturer: OutputCapturerDict,
) -> None:
    """Test filtering on node, then visit."""
    session = fixture_abs_path("test_filter_on_node_visit.session")
    execution.run(
        filename=fixture_abs_path("simple_node_connection.jac"),
        session=session,
    )
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("simple_node_connection.jac"),
        session=session,
        entrypoint="filter_on_node_visit",
        args=[],
    )
    assert output_capturer["get"]().strip() == "simple(tag='first')"
    del_session(session)


def test_indirect_reference_node(
    output_capturer: OutputCapturerDict,
) -> None:
    """Test reference node indirectly without visiting."""
    session = fixture_abs_path("test_indirect_reference_node.session")
    execution.enter(
        filename=fixture_abs_path("simple_persistent.jac"),
        session=session,
        entrypoint="create",
        args=[],
    )
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("simple_persistent.jac"),
        session=session,
        entrypoint="indirect_ref",
        args=[],
    )
    # FIXME: Figure out what to do with warning.
    # assert output_capturer["get"]().strip() == "[b(name='node b')]\n[GenericEdge()]"
    del_session(session)


def test_walker_purger(
    output_capturer: OutputCapturerDict,
) -> None:
    """Test simple persistent object."""
    session = fixture_abs_path("test_walker_purger.session")
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("graph_purger.jac"),
        session=session,
        entrypoint="populate",
        args=[],
    )
    execution.enter(
        filename=fixture_abs_path("graph_purger.jac"),
        session=session,
        entrypoint="traverse",
        args=[],
    )
    execution.enter(
        filename=fixture_abs_path("graph_purger.jac"),
        session=session,
        entrypoint="check",
        args=[],
    )
    execution.enter(
        filename=fixture_abs_path("graph_purger.jac"),
        session=session,
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
        session=session,
        entrypoint="traverse",
        args=[],
    )
    execution.enter(
        filename=fixture_abs_path("graph_purger.jac"),
        session=session,
        entrypoint="check",
        args=[],
    )
    execution.enter(
        filename=fixture_abs_path("graph_purger.jac"),
        session=session,
        entrypoint="purge",
        args=[],
    )
    output = output_capturer["get"]().strip()
    assert output == "Root()\n1\n0"
    del_session(session)


def trigger_access_validation_test(
    output_capturer: OutputCapturerDict,
    roots: list[str],
    nodes: list[str],
    give_access_to_full_graph: bool,
    via_all: bool = False,
) -> None:
    """Test different access validation."""
    global session
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
        session=session,
        root=roots[0],
        node=node_1,
    )
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="allow_other_root_access",
        args=[roots[0], 0, via_all],
        session=session,
        root=roots[1],
        node=node_2,
    )

    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="update_node",
        args=[20],
        session=session,
        root=roots[0],
        node=nodes[1],
    )
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="update_node",
        args=[10],
        session=session,
        root=roots[1],
        node=nodes[0],
    )

    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="update_target_node",
        args=[20, nodes[1]],
        session=session,
        root=roots[0],
    )

    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="update_target_node",
        args=[10, nodes[0]],
        session=session,
        root=roots[1],
    )

    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        session=session,
        root=roots[0],
        node=nodes[1],
    )
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        session=session,
        root=roots[1],
        node=nodes[0],
    )
    archs = output_capturer["get"]().strip().split("\n")
    assert len(archs) == 2

    # --------- NO UPDATE SHOULD HAPPEN -------- #

    assert archs[0] == "A(val=2)"
    assert archs[1] == "A(val=1)"

    ##############################################
    #        WITH READ ACCESS BUT ELEVATED       #
    ##############################################

    output_capturer["start"]()

    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="update_node_forced",
        args=[20],
        session=session,
        root=roots[0],
        node=nodes[1],
    )
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="update_node_forced",
        args=[10],
        session=session,
        root=roots[1],
        node=nodes[0],
    )

    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        session=session,
        root=roots[0],
        node=nodes[1],
    )
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        session=session,
        root=roots[1],
        node=nodes[0],
    )
    archs = output_capturer["get"]().strip().split("\n")
    assert len(archs) == 2

    # ---------- UPDATE SHOULD HAPPEN ---------- #

    assert archs[0] == "A(val=20)"
    assert archs[1] == "A(val=10)"

    # ---------- DISALLOW READ ACCESS ---------- #

    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="disallow_other_root_access",
        args=[roots[1], via_all],
        session=session,
        root=roots[0],
        node=node_1,
    )
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="disallow_other_root_access",
        args=[roots[0], via_all],
        session=session,
        root=roots[1],
        node=node_2,
    )

    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        session=session,
        root=roots[0],
        node=nodes[1],
    )
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        session=session,
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
        session=session,
        root=roots[0],
        node=node_1,
    )
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="allow_other_root_access",
        args=[roots[0], "WRITE", via_all],
        session=session,
        root=roots[1],
        node=node_2,
    )

    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="update_node",
        args=[200],
        root=roots[0],
        node=nodes[1],
        session=session,
    )
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="update_node",
        args=[100],
        session=session,
        root=roots[1],
        node=nodes[0],
    )

    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        session=session,
        root=roots[0],
        node=nodes[1],
    )
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        session=session,
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
        session=session,
        root=roots[0],
        node=node_1,
    )
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="disallow_other_root_access",
        args=[roots[0], via_all],
        session=session,
        root=roots[1],
        node=node_2,
    )

    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        session=session,
        root=roots[0],
        node=nodes[1],
    )
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        session=session,
        root=roots[1],
        node=nodes[0],
    )
    assert not output_capturer["get"]().strip()

    # ---------- ROOTS RESET OWN NODE ---------- #

    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="update_node",
        args=[1],
        session=session,
        root=roots[0],
        node=nodes[0],
    )
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="update_node",
        args=[2],
        session=session,
        root=roots[1],
        node=nodes[1],
    )


def test_other_root_access(
    output_capturer: OutputCapturerDict,
) -> None:
    """Test filtering on node, then visit."""
    global session
    session = fixture_abs_path("other_root_access.session")

    ##############################################
    #                CREATE ROOTS                #
    ##############################################

    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="create_other_root",
        args=[],
        session=session,
    )
    root1 = output_capturer["get"]().strip()

    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="create_other_root",
        args=[],
        session=session,
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
        session=session,
        root=root1,
    )
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="create_node",
        args=[2],
        session=session,
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
        session=session,
        root=root1,
    )
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        session=session,
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
        session=session,
        root=root1,
        node=nodes[1],
    )
    execution.enter(
        filename=fixture_abs_path("other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        session=session,
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

    del_session(session)


def test_savable_object(
    output_capturer: OutputCapturerDict,
) -> None:
    """Test ObjectAnchor save."""
    global session
    session = fixture_abs_path("savable_object.session")

    output_capturer["start"]()

    execution.enter(
        filename=fixture_abs_path("savable_object.jac"),
        entrypoint="create_custom_object",
        args=[],
        session=session,
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
        session=session,
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
        session=session,
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
        session=session,
    )

    execution.enter(
        filename=fixture_abs_path("savable_object.jac"),
        entrypoint="get_custom_object",
        args=[id],
        session=session,
    )
    assert output_capturer["get"]().strip() == "None"

    del_session(session)


def test_traversing_save(
    output_capturer: OutputCapturerDict,
) -> None:
    """Test traversing save."""
    global session
    session = fixture_abs_path("traversing_save.session")

    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("traversing_save.jac"),
        entrypoint="build",
        args=[],
        session=session,
    )

    execution.enter(
        filename=fixture_abs_path("traversing_save.jac"),
        entrypoint="view",
        args=[],
        session=session,
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

    del_session(session)


def test_custom_access_validation(
    output_capturer: OutputCapturerDict,
) -> None:
    """Test custom access validation."""
    global session
    session = fixture_abs_path("custom_access_validation.session")

    ##############################################
    #              CREATE OTHER ROOT             #
    ##############################################

    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("custom_access_validation.jac"),
        entrypoint="create_other_root",
        args=[],
        session=session,
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
        session=session,
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
        session=session,
        node=node,
    )

    assert output_capturer["get"]().strip() == "A(val1='NO_ACCESS', val2=0)"

    # BY OTHER
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("custom_access_validation.jac"),
        entrypoint="check",
        args=[],
        session=session,
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
        session=session,
        node=node,
    )

    # CHECK BY OTHER
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("custom_access_validation.jac"),
        entrypoint="check",
        args=[],
        session=session,
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
        session=session,
        root=other_root,
        node=node,
    )

    # CHECK BY OTHER
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("custom_access_validation.jac"),
        entrypoint="check",
        args=[],
        session=session,
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
        session=session,
        node=node,
    )

    # UPDATE BY OTHER
    execution.enter(
        filename=fixture_abs_path("custom_access_validation.jac"),
        entrypoint="update",
        args=[None, 2],
        session=session,
        root=other_root,
        node=node,
    )

    # CHECK BY OTHER
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("custom_access_validation.jac"),
        entrypoint="check",
        args=[],
        session=session,
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
        session=session,
        node=node,
    )

    # UPDATE BY OTHER
    execution.enter(
        filename=fixture_abs_path("custom_access_validation.jac"),
        entrypoint="update",
        args=[None, 5],
        session=session,
        root=other_root,
        node=node,
    )

    # CHECK BY OTHER
    output_capturer["start"]()
    execution.enter(
        filename=fixture_abs_path("custom_access_validation.jac"),
        entrypoint="check",
        args=[],
        session=session,
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
        session=session,
        node=node,
    )

    assert output_capturer["get"]().strip() == "A(val1='NO_ACCESS', val2=2)"


def test_run_persistent_reuse():
    """Test that execution.run with session persists nodes to session file."""
    import shelve

    session = fixture_abs_path("test_run_persistent_reuse.session")

    ##############################################
    #          FIRST RUN - CREATE NODES          #
    ##############################################

    execution.run(
        filename=fixture_abs_path("simple_node_connection.jac"),
        session=session,
    )

    # Check session file directly (not via get_object which re-runs code)
    with shelve.open(session) as shelf:
        root = shelf["00000000-0000-0000-0000-000000000000"]
        first_run_edges = len(root.edges)
        first_run_keys = len(shelf.keys())

    # Should have root + 2 nodes + 2 edges = 5 keys
    assert first_run_keys > 1, "First run should persist nodes to session file"
    assert first_run_edges == 2, "Root should have 2 edges after first run"

    ##############################################
    #    SECOND RUN - SHOULD REUSE, NOT          #
    #              RECREATE NODES                #
    ##############################################

    execution.run(
        filename=fixture_abs_path("simple_node_connection.jac"),
        session=session,
    )

    # Check session file again
    with shelve.open(session) as shelf:
        root = shelf["00000000-0000-0000-0000-000000000000"]
        second_run_edges = len(root.edges)
        second_run_keys = len(shelf.keys())

    # Should have same number of keys (not doubled)
    assert second_run_keys == first_run_keys, (
        "Second run should reuse persisted nodes, not create duplicates"
    )
    assert second_run_edges == 2, "Root should still have only 2 edges (not 4)"

    del_session(session)
