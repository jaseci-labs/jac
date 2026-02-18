"""Test for jaseci plugin."""

import io;
import os;
import sys;
import shutil;
import from pathlib { Path }
import from tempfile { mkdtemp }
import jaclang;
import from jaclang { JacRuntime as Jac }
import from jaclang.cli.commands { execution }
import from tests.conftest { get_object }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     FIXTURES = os.path.join(JAC_ROOT, "tests", "runtimelib", "fixtures");

def capture_start -> io.StringIO {
    captured = io.StringIO();
    sys.stdout = captured;
    return captured;
}

def capture_get(captured: io.StringIO) -> str {
    sys.stdout = sys.__stdout__;
    return captured.getvalue();
}

def trigger_access_validation_test(
    roots: list, nodes: list, give_access_to_full_graph: bool, via_all: bool = False
) {
    """Test different access validation."""
    captured = capture_start();

    ##############################################
    #              ALLOW READ ACCESS             #
    ##############################################
    node_1 = "" if give_access_to_full_graph else nodes[0];
    node_2 = "" if give_access_to_full_graph else nodes[1];

    execution.enter(
        filename=os.path.join(FIXTURES, "other_root_access.jac"),
        entrypoint="allow_other_root_access",
        args=[roots[1], 0, via_all],
        **{"root": roots[0]},
        nd=node_1
    );
    execution.enter(
        filename=os.path.join(FIXTURES, "other_root_access.jac"),
        entrypoint="allow_other_root_access",
        args=[roots[0], 0, via_all],
        **{"root": roots[1]},
        nd=node_2
    );

    execution.enter(
        filename=os.path.join(FIXTURES, "other_root_access.jac"),
        entrypoint="update_node",
        args=[20],
        **{"root": roots[0]},
        nd=nodes[1]
    );
    execution.enter(
        filename=os.path.join(FIXTURES, "other_root_access.jac"),
        entrypoint="update_node",
        args=[10],
        **{"root": roots[1]},
        nd=nodes[0]
    );

    execution.enter(
        filename=os.path.join(FIXTURES, "other_root_access.jac"),
        entrypoint="update_target_node",
        args=[20, nodes[1]],
        **{"root": roots[0]}
    );

    execution.enter(
        filename=os.path.join(FIXTURES, "other_root_access.jac"),
        entrypoint="update_target_node",
        args=[10, nodes[0]],
        **{"root": roots[1]}
    );

    execution.enter(
        filename=os.path.join(FIXTURES, "other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        **{"root": roots[0]},
        nd=nodes[1]
    );
    execution.enter(
        filename=os.path.join(FIXTURES, "other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        **{"root": roots[1]},
        nd=nodes[0]
    );
    archs = capture_get(captured).strip().split("\n");
    assert len(archs) == 2;

    # --------- NO UPDATE SHOULD HAPPEN -------- #
    assert archs[0] == "A(val=2)";
    assert archs[1] == "A(val=1)";

    # ---------- DISALLOW READ ACCESS ---------- #
    captured = capture_start();
    execution.enter(
        filename=os.path.join(FIXTURES, "other_root_access.jac"),
        entrypoint="disallow_other_root_access",
        args=[roots[1], via_all],
        **{"root": roots[0]},
        nd=node_1
    );
    execution.enter(
        filename=os.path.join(FIXTURES, "other_root_access.jac"),
        entrypoint="disallow_other_root_access",
        args=[roots[0], via_all],
        **{"root": roots[1]},
        nd=node_2
    );

    execution.enter(
        filename=os.path.join(FIXTURES, "other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        **{"root": roots[0]},
        nd=nodes[1]
    );
    execution.enter(
        filename=os.path.join(FIXTURES, "other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        **{"root": roots[1]},
        nd=nodes[0]
    );
    assert not capture_get(captured).strip();

    ##############################################
    #             ALLOW WRITE ACCESS             #
    ##############################################
    captured = capture_start();
    execution.enter(
        filename=os.path.join(FIXTURES, "other_root_access.jac"),
        entrypoint="allow_other_root_access",
        args=[roots[1], "WRITE", via_all],
        **{"root": roots[0]},
        nd=node_1
    );
    execution.enter(
        filename=os.path.join(FIXTURES, "other_root_access.jac"),
        entrypoint="allow_other_root_access",
        args=[roots[0], "WRITE", via_all],
        **{"root": roots[1]},
        nd=node_2
    );

    execution.enter(
        filename=os.path.join(FIXTURES, "other_root_access.jac"),
        entrypoint="update_node",
        args=[200],
        **{"root": roots[0]},
        nd=nodes[1]
    );
    execution.enter(
        filename=os.path.join(FIXTURES, "other_root_access.jac"),
        entrypoint="update_node",
        args=[100],
        **{"root": roots[1]},
        nd=nodes[0]
    );

    execution.enter(
        filename=os.path.join(FIXTURES, "other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        **{"root": roots[0]},
        nd=nodes[1]
    );
    execution.enter(
        filename=os.path.join(FIXTURES, "other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        **{"root": roots[1]},
        nd=nodes[0]
    );
    archs = capture_get(captured).strip().split("\n");
    assert len(archs) == 2;

    # ---------- UPDATE SHOULD HAPPEN ---------- #
    assert archs[0] == "A(val=200)";
    assert archs[1] == "A(val=100)";

    # ---------- DISALLOW WRITE ACCESS --------- #
    captured = capture_start();
    execution.enter(
        filename=os.path.join(FIXTURES, "other_root_access.jac"),
        entrypoint="disallow_other_root_access",
        args=[roots[1], via_all],
        **{"root": roots[0]},
        nd=node_1
    );
    execution.enter(
        filename=os.path.join(FIXTURES, "other_root_access.jac"),
        entrypoint="disallow_other_root_access",
        args=[roots[0], via_all],
        **{"root": roots[1]},
        nd=node_2
    );

    execution.enter(
        filename=os.path.join(FIXTURES, "other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        **{"root": roots[0]},
        nd=nodes[1]
    );
    execution.enter(
        filename=os.path.join(FIXTURES, "other_root_access.jac"),
        entrypoint="check_node",
        args=[],
        **{"root": roots[1]},
        nd=nodes[0]
    );
    assert not capture_get(captured).strip();

    # ---------- ROOTS RESET OWN NODE ---------- #
    captured = capture_start();

    execution.enter(
        filename=os.path.join(FIXTURES, "other_root_access.jac"),
        entrypoint="update_node",
        args=[1],
        **{"root": roots[0]},
        nd=nodes[0]
    );
    execution.enter(
        filename=os.path.join(FIXTURES, "other_root_access.jac"),
        entrypoint="update_node",
        args=[2],
        **{"root": roots[1]},
        nd=nodes[1]
    );
    capture_get(captured);
}

test "walker simple persistent" {
    _tmpdir = mkdtemp();
    _orig_base = Jac.base_path_dir;
    Jac.set_base_path(_tmpdir);
    try {
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "simple_persistent.jac"),
            entrypoint="create",
            args=[]
        );
        execution.enter(
            filename=os.path.join(FIXTURES, "simple_persistent.jac"),
            entrypoint="traverse",
            args=[]
        );
        output = capture_get(captured).strip();
        assert output == "node a\nnode b";
    } finally {
        Jac.set_base_path(_orig_base);
        shutil.rmtree(_tmpdir, ignore_errors=True);
    }
}

test "entrypoint root" {
    _tmpdir = mkdtemp();
    _orig_base = Jac.base_path_dir;
    Jac.set_base_path(_tmpdir);
    try {
        execution.enter(
            filename=os.path.join(FIXTURES, "simple_persistent.jac"),
            entrypoint="create",
            args=[]
        );
        root_obj = get_object(
            filename=os.path.join(FIXTURES, "simple_persistent.jac"), id="root"
        );
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "simple_persistent.jac"),
            entrypoint="traverse",
            args=[],
            nd=str(root_obj["id"])
        );
        output = capture_get(captured).strip();
        assert output == "node a\nnode b";
    } finally {
        Jac.set_base_path(_orig_base);
        shutil.rmtree(_tmpdir, ignore_errors=True);
    }
}

test "entrypoint non root" {
    _tmpdir = mkdtemp();
    _orig_base = Jac.base_path_dir;
    Jac.set_base_path(_tmpdir);
    try {
        execution.enter(
            filename=os.path.join(FIXTURES, "simple_persistent.jac"),
            entrypoint="create",
            args=[]
        );
        root_obj = get_object(
            filename=os.path.join(FIXTURES, "simple_persistent.jac"), id="root"
        );
        edge_obj = get_object(
            filename=os.path.join(FIXTURES, "simple_persistent.jac"),
            id=root_obj["edges"][0].id.hex
        );
        a_obj = get_object(
            filename=os.path.join(FIXTURES, "simple_persistent.jac"),
            id=edge_obj["target"].id.hex
        );
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "simple_persistent.jac"),
            entrypoint="traverse",
            nd=str(a_obj["id"]),
            args=[]
        );
        output = capture_get(captured).strip();
        assert output == "node a\nnode b";
    } finally {
        Jac.set_base_path(_orig_base);
        shutil.rmtree(_tmpdir, ignore_errors=True);
    }
}

test "get edge" {
    _tmpdir = mkdtemp();
    _orig_base = Jac.base_path_dir;
    Jac.set_base_path(_tmpdir);
    try {
        execution.run(filename=os.path.join(FIXTURES, "simple_node_connection.jac"));
        root_obj = get_object(
            filename=os.path.join(FIXTURES, "simple_node_connection.jac"), id="root"
        );
        assert len(root_obj["edges"]) == 2;
        edge_objs = [
            get_object(
                filename=os.path.join(FIXTURES, "simple_node_connection.jac"),
                id=e.id.hex
            ) for e in root_obj["edges"]
        ];
        node_ids = [eo["target"].id.hex for eo in edge_objs];
        node_objs = [
            get_object(
                filename=os.path.join(FIXTURES, "simple_node_connection.jac"),
                id=str(n_id)
            ) for n_id in node_ids
        ];
        assert len(node_objs) == 2;
        assert {no["archetype"].tag for no in node_objs} == {"first","second"};
    } finally {
        Jac.set_base_path(_orig_base);
        shutil.rmtree(_tmpdir, ignore_errors=True);
    }
}

test "filter on edge get edge" {
    _tmpdir = mkdtemp();
    _orig_base = Jac.base_path_dir;
    Jac.set_base_path(_tmpdir);
    try {
        execution.run(filename=os.path.join(FIXTURES, "simple_node_connection.jac"));
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "simple_node_connection.jac"),
            entrypoint="filter_on_edge_get_edge",
            args=[]
        );
        assert capture_get(captured).strip() == "[simple_edge(index=1)]";
    } finally {
        Jac.set_base_path(_orig_base);
        shutil.rmtree(_tmpdir, ignore_errors=True);
    }
}

test "filter on edge get node" {
    _tmpdir = mkdtemp();
    _orig_base = Jac.base_path_dir;
    Jac.set_base_path(_tmpdir);
    try {
        execution.run(filename=os.path.join(FIXTURES, "simple_node_connection.jac"));
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "simple_node_connection.jac"),
            entrypoint="filter_on_edge_get_node",
            args=[]
        );
        assert capture_get(captured).strip() == "[simple(tag='second')]";
    } finally {
        Jac.set_base_path(_orig_base);
        shutil.rmtree(_tmpdir, ignore_errors=True);
    }
}

test "filter on node get node" {
    _tmpdir = mkdtemp();
    _orig_base = Jac.base_path_dir;
    Jac.set_base_path(_tmpdir);
    try {
        execution.run(filename=os.path.join(FIXTURES, "simple_node_connection.jac"));
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "simple_node_connection.jac"),
            entrypoint="filter_on_node_get_node",
            args=[]
        );
        assert capture_get(captured).strip() == "[simple(tag='second')]";
    } finally {
        Jac.set_base_path(_orig_base);
        shutil.rmtree(_tmpdir, ignore_errors=True);
    }
}

test "filter on edge visit" {
    _tmpdir = mkdtemp();
    _orig_base = Jac.base_path_dir;
    Jac.set_base_path(_tmpdir);
    try {
        execution.run(filename=os.path.join(FIXTURES, "simple_node_connection.jac"));
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "simple_node_connection.jac"),
            entrypoint="filter_on_edge_visit",
            args=[]
        );
        assert capture_get(captured).strip() == "simple(tag='first')";
    } finally {
        Jac.set_base_path(_orig_base);
        shutil.rmtree(_tmpdir, ignore_errors=True);
    }
}

test "filter on node visit" {
    _tmpdir = mkdtemp();
    _orig_base = Jac.base_path_dir;
    Jac.set_base_path(_tmpdir);
    try {
        execution.run(filename=os.path.join(FIXTURES, "simple_node_connection.jac"));
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "simple_node_connection.jac"),
            entrypoint="filter_on_node_visit",
            args=[]
        );
        assert capture_get(captured).strip() == "simple(tag='first')";
    } finally {
        Jac.set_base_path(_orig_base);
        shutil.rmtree(_tmpdir, ignore_errors=True);
    }
}

test "indirect reference node" {
    _tmpdir = mkdtemp();
    _orig_base = Jac.base_path_dir;
    Jac.set_base_path(_tmpdir);
    try {
        execution.enter(
            filename=os.path.join(FIXTURES, "simple_persistent.jac"),
            entrypoint="create",
            args=[]
        );
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "simple_persistent.jac"),
            entrypoint="indirect_ref",
            args=[]
        );
        capture_get(captured);
        # FIXME: Figure out what to do with warning.
        # assert output == "[b(name='node b')]\n[GenericEdge()]"
    } finally {
        Jac.set_base_path(_orig_base);
        shutil.rmtree(_tmpdir, ignore_errors=True);
    }
}

test "walker purger" {
    _tmpdir = mkdtemp();
    _orig_base = Jac.base_path_dir;
    Jac.set_base_path(_tmpdir);
    try {
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "graph_purger.jac"),
            entrypoint="populate",
            args=[]
        );
        execution.enter(
            filename=os.path.join(FIXTURES, "graph_purger.jac"),
            entrypoint="traverse",
            args=[]
        );
        execution.enter(
            filename=os.path.join(FIXTURES, "graph_purger.jac"),
            entrypoint="check",
            args=[]
        );
        execution.enter(
            filename=os.path.join(FIXTURES, "graph_purger.jac"),
            entrypoint="purge",
            args=[]
        );
        output = capture_get(captured).strip();
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
        );
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "graph_purger.jac"),
            entrypoint="traverse",
            args=[]
        );
        execution.enter(
            filename=os.path.join(FIXTURES, "graph_purger.jac"),
            entrypoint="check",
            args=[]
        );
        execution.enter(
            filename=os.path.join(FIXTURES, "graph_purger.jac"),
            entrypoint="purge",
            args=[]
        );
        output = capture_get(captured).strip();
        assert output == "Root()\n1\n0";
    } finally {
        Jac.set_base_path(_orig_base);
        shutil.rmtree(_tmpdir, ignore_errors=True);
    }
}

test "other root access" {
    _tmpdir = mkdtemp();
    _orig_base = Jac.base_path_dir;
    Jac.set_base_path(_tmpdir);
    try {
        ##############################################
        #                CREATE ROOTS                #
        ##############################################
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "other_root_access.jac"),
            entrypoint="create_other_root",
            args=[]
        );
        root1 = capture_get(captured).strip();

        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "other_root_access.jac"),
            entrypoint="create_other_root",
            args=[]
        );
        root2 = capture_get(captured).strip();

        ##############################################
        #           CREATE RESPECTIVE NODES          #
        ##############################################
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "other_root_access.jac"),
            entrypoint="create_node",
            args=[1],
            **{"root": root1}
        );
        execution.enter(
            filename=os.path.join(FIXTURES, "other_root_access.jac"),
            entrypoint="create_node",
            args=[2],
            **{"root": root2}
        );
        nodes = capture_get(captured).strip().split("\n");
        assert len(nodes) == 2;

        ##############################################
        #           VISIT RESPECTIVE NODES           #
        ##############################################
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "other_root_access.jac"),
            entrypoint="check_node",
            args=[],
            **{"root": root1}
        );
        execution.enter(
            filename=os.path.join(FIXTURES, "other_root_access.jac"),
            entrypoint="check_node",
            args=[],
            **{"root": root2}
        );
        archs = capture_get(captured).strip().split("\n");
        assert len(archs) == 2;
        assert archs[0] == "A(val=1)";
        assert archs[1] == "A(val=2)";

        ##############################################
        #              SWAP TARGET NODE              #
        #                  NO ACCESS                 #
        ##############################################
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "other_root_access.jac"),
            entrypoint="check_node",
            args=[],
            **{"root": root1},
            nd=nodes[1]
        );
        execution.enter(
            filename=os.path.join(FIXTURES, "other_root_access.jac"),
            entrypoint="check_node",
            args=[],
            **{"root": root2},
            nd=nodes[0]
        );
        assert not capture_get(captured).strip();

        ##############################################
        #        TEST DIFFERENT ACCESS OPTIONS       #
        ##############################################
        roots = [root1, root2];

        trigger_access_validation_test(roots, nodes, give_access_to_full_graph=False);
        trigger_access_validation_test(roots, nodes, give_access_to_full_graph=True);

        trigger_access_validation_test(
            roots, nodes, give_access_to_full_graph=False, via_all=True
        );
        trigger_access_validation_test(
            roots, nodes, give_access_to_full_graph=True, via_all=True
        );
    } finally {
        Jac.set_base_path(_orig_base);
        shutil.rmtree(_tmpdir, ignore_errors=True);
    }
}

test "savable object" {
    _tmpdir = mkdtemp();
    _orig_base = Jac.base_path_dir;
    Jac.set_base_path(_tmpdir);
    try {
        captured = capture_start();

        execution.enter(
            filename=os.path.join(FIXTURES, "savable_object.jac"),
            entrypoint="create_custom_object",
            args=[]
        );

        prints = capture_get(captured).strip().split("\n");
        id = prints[0];

        assert prints[1] == (
            "SavableObject(val=0, arr=[], json={}, parent=Parent(val=1, arr=[1], json"
            "={'a': 1}, enum_field=<Enum.B: 'b'>, child=Child(val=2, arr=[1, 2], json"
            "={'a': 1, 'b': 2}, enum_field=<Enum.C: 'c'>)), enum_field=<Enum.A: 'a'>)"
        );

        captured = capture_start();

        execution.enter(
            filename=os.path.join(FIXTURES, "savable_object.jac"),
            entrypoint="get_custom_object",
            args=[id]
        );
        assert capture_get(captured).strip() == (
            "SavableObject(val=0, arr=[], json={}, parent=Parent(val=1, arr=[1], json"
            "={'a': 1}, enum_field=<Enum.B: 'b'>, child=Child(val=2, arr=[1, 2], json"
            "={'a': 1, 'b': 2}, enum_field=<Enum.C: 'c'>)), enum_field=<Enum.A: 'a'>)"
        );

        captured = capture_start();

        execution.enter(
            filename=os.path.join(FIXTURES, "savable_object.jac"),
            entrypoint="update_custom_object",
            args=[id]
        );

        assert capture_get(captured).strip() == (
            "SavableObject(val=1, arr=[1], json={'a': 1}, parent=Parent(val=2, arr=[1, 2], json"
            "={'a': 1, 'b': 2}, enum_field=<Enum.C: 'c'>, child=Child(val=3, arr=[1, 2, 3], json"
            "={'a': 1, 'b': 2, 'c': 3}, enum_field=<Enum.A: 'a'>)), enum_field=<Enum.B: 'b'>)"
        );

        captured = capture_start();

        execution.enter(
            filename=os.path.join(FIXTURES, "savable_object.jac"),
            entrypoint="delete_custom_object",
            args=[id]
        );

        execution.enter(
            filename=os.path.join(FIXTURES, "savable_object.jac"),
            entrypoint="get_custom_object",
            args=[id]
        );
        assert capture_get(captured).strip() == "None";
    } finally {
        Jac.set_base_path(_orig_base);
        shutil.rmtree(_tmpdir, ignore_errors=True);
    }
}

test "traversing save" {
    _tmpdir = mkdtemp();
    _orig_base = Jac.base_path_dir;
    Jac.set_base_path(_tmpdir);
    try {
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "traversing_save.jac"),
            entrypoint="build",
            args=[]
        );

        execution.enter(
            filename=os.path.join(FIXTURES, "traversing_save.jac"),
            entrypoint="view",
            args=[]
        );

        assert capture_get(captured).strip() == (
            "digraph {\n"
            "node [style=\"filled\", shape=\"ellipse\", fillcolor=\"invis\", fontcolor=\"black\"];\n"
            "0 -> 1 [label=\"\"];\n"
            "1 -> 2 [label=\"\"];\n"
            "0 [label=\"Root()\"fillcolor=\"#FFE9E9\"];\n"
            "1 [label=\"A()\"fillcolor=\"#F0FFF0\"];\n"
            "2 [label=\"B()\"fillcolor=\"#F5E5FF\"];\n}"
        );
    } finally {
        Jac.set_base_path(_orig_base);
        shutil.rmtree(_tmpdir, ignore_errors=True);
    }
}

test "custom access validation" {
    _tmpdir = mkdtemp();
    _orig_base = Jac.base_path_dir;
    Jac.set_base_path(_tmpdir);
    try {
        ##############################################
        #              CREATE OTHER ROOT             #
        ##############################################
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "custom_access_validation.jac"),
            entrypoint="create_other_root",
            args=[]
        );

        other_root = capture_get(captured).strip();

        ##############################################
        #                 CREATE NODE                #
        ##############################################
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "custom_access_validation.jac"),
            entrypoint="create",
            args=[]
        );
        nd_str = capture_get(captured).strip();

        ##############################################
        #                 CHECK NODE                 #
        ##############################################

        # BY OWNER
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "custom_access_validation.jac"),
            entrypoint="check",
            args=[],
            nd=nd_str
        );

        assert capture_get(captured).strip() == "A(val1='NO_ACCESS', val2=0)";

        # BY OTHER
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "custom_access_validation.jac"),
            entrypoint="check",
            args=[],
            **{"root": other_root},
            nd=nd_str
        );

        assert capture_get(captured).strip() == "";

        ##############################################
        #       UPDATE NODE (GIVE READ ACCESS)       #
        ##############################################

        # UPDATE BY OWNER
        execution.enter(
            filename=os.path.join(FIXTURES, "custom_access_validation.jac"),
            entrypoint="update",
            args=["READ", None],
            nd=nd_str
        );

        # CHECK BY OTHER
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "custom_access_validation.jac"),
            entrypoint="check",
            args=[],
            **{"root": other_root},
            nd=nd_str
        );

        assert capture_get(captured).strip() == "A(val1='READ', val2=0)";

        ##############################################
        #     UPDATE NODE (BUT STILL READ ACCESS)    #
        ##############################################

        # UPDATE BY OTHER
        execution.enter(
            filename=os.path.join(FIXTURES, "custom_access_validation.jac"),
            entrypoint="update",
            args=[None, 1],
            **{"root": other_root},
            nd=nd_str
        );

        # CHECK BY OTHER
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "custom_access_validation.jac"),
            entrypoint="check",
            args=[],
            **{"root": other_root},
            nd=nd_str
        );

        assert capture_get(captured).strip() == "A(val1='READ', val2=0)";

        ##############################################
        #       UPDATE NODE (GIVE WRITE ACCESS)      #
        ##############################################

        # UPDATE BY OWNER
        execution.enter(
            filename=os.path.join(FIXTURES, "custom_access_validation.jac"),
            entrypoint="update",
            args=["WRITE", None],
            nd=nd_str
        );

        # UPDATE BY OTHER
        execution.enter(
            filename=os.path.join(FIXTURES, "custom_access_validation.jac"),
            entrypoint="update",
            args=[None, 2],
            **{"root": other_root},
            nd=nd_str
        );

        # CHECK BY OTHER
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "custom_access_validation.jac"),
            entrypoint="check",
            args=[],
            **{"root": other_root},
            nd=nd_str
        );

        assert capture_get(captured).strip() == "A(val1='WRITE', val2=2)";

        ##############################################
        #         UPDATE NODE (REMOVE ACCESS)        #
        ##############################################

        # UPDATE BY OWNER
        execution.enter(
            filename=os.path.join(FIXTURES, "custom_access_validation.jac"),
            entrypoint="update",
            args=["NO_ACCESS", None],
            nd=nd_str
        );

        # UPDATE BY OTHER
        execution.enter(
            filename=os.path.join(FIXTURES, "custom_access_validation.jac"),
            entrypoint="update",
            args=[None, 5],
            **{"root": other_root},
            nd=nd_str
        );

        # CHECK BY OTHER
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "custom_access_validation.jac"),
            entrypoint="check",
            args=[],
            **{"root": other_root},
            nd=nd_str
        );

        assert capture_get(captured).strip() == "";

        # CHECK BY OWNER
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "custom_access_validation.jac"),
            entrypoint="check",
            args=[],
            nd=nd_str
        );

        assert capture_get(captured).strip() == "A(val1='NO_ACCESS', val2=2)";
    } finally {
        Jac.set_base_path(_orig_base);
        shutil.rmtree(_tmpdir, ignore_errors=True);
    }
}

test "run persistent reuse" {
    import sqlite3;
    import from pickle { loads }

    _tmpdir = mkdtemp();
    _orig_base = Jac.base_path_dir;
    Jac.set_base_path(_tmpdir);
    try {
        # Database path is auto-generated at _tmpdir/.jac/data/main.db
        db_path = os.path.join(_tmpdir, ".jac", "data", "main.db");

        ##############################################
        #          FIRST RUN - CREATE NODES          #
        ##############################################
        execution.run(filename=os.path.join(FIXTURES, "simple_node_connection.jac"));

        # Check database directly (not via get_object which re-runs code)
        conn = sqlite3.connect(str(db_path));
        cursor = conn.execute(
            "SELECT data FROM anchors WHERE id = ?",
            ("00000000-0000-0000-0000-000000000000", )
        );
        row = cursor.fetchone();
        assert row is not None , "Root should be persisted to database";
        root_data = loads(row[0]);
        first_run_edges = len(root_data.edges);
        cursor = conn.execute("SELECT COUNT(*) FROM anchors");
        first_run_keys = cursor.fetchone()[0];
        conn.close();

        # Should have root + 2 nodes + 2 edges = 5 keys
        assert first_run_keys > 1 , "First run should persist nodes to database";
        assert first_run_edges == 2 , "Root should have 2 edges after first run";

        ##############################################
        #    SECOND RUN - SHOULD REUSE, NOT          #
        #              RECREATE NODES                #
        ##############################################
        execution.run(filename=os.path.join(FIXTURES, "simple_node_connection.jac"));

        # Check database again
        conn = sqlite3.connect(str(db_path));
        cursor = conn.execute(
            "SELECT data FROM anchors WHERE id = ?",
            ("00000000-0000-0000-0000-000000000000", )
        );
        row = cursor.fetchone();
        root_data = loads(row[0]);
        second_run_edges = len(root_data.edges);
        cursor = conn.execute("SELECT COUNT(*) FROM anchors");
        second_run_keys = cursor.fetchone()[0];
        conn.close();

        # Should have same number of keys (not doubled)
        assert second_run_keys == first_run_keys , (
            "Second run should reuse persisted nodes, not create duplicates"
        );
        assert second_run_edges == 2 , "Root should still have only 2 edges (not 4)";
    } finally {
        Jac.set_base_path(_orig_base);
        shutil.rmtree(_tmpdir, ignore_errors=True);
    }
}

test "user isolation via set user root" {
    _tmpdir = mkdtemp();
    _orig_base = Jac.base_path_dir;
    Jac.set_base_path(_tmpdir);
    try {
        # Create two separate user roots
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "other_root_access.jac"),
            entrypoint="create_other_root",
            args=[]
        );
        user1_root = capture_get(captured).strip();

        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "other_root_access.jac"),
            entrypoint="create_other_root",
            args=[]
        );
        user2_root = capture_get(captured).strip();

        # Verify different roots were created
        assert user1_root != user2_root , "Each user should have a unique root";

        # User 1 creates a node with val=100
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "other_root_access.jac"),
            entrypoint="create_node",
            args=[100],
            **{"root": user1_root}
        );
        user1_node = capture_get(captured).strip();

        # User 2 creates a node with val=200
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "other_root_access.jac"),
            entrypoint="create_node",
            args=[200],
            **{"root": user2_root}
        );
        user2_node = capture_get(captured).strip();

        # Verify user 1 can only see their own node (val=100)
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "other_root_access.jac"),
            entrypoint="check_node",
            args=[],
            **{"root": user1_root}
        );
        user1_sees = capture_get(captured).strip();
        assert user1_sees == "A(val=100)" , (
            f"User 1 should see their node, got: {user1_sees}"
        );

        # Verify user 2 can only see their own node (val=200)
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "other_root_access.jac"),
            entrypoint="check_node",
            args=[],
            **{"root": user2_root}
        );
        user2_sees = capture_get(captured).strip();
        assert user2_sees == "A(val=200)" , (
            f"User 2 should see their node, got: {user2_sees}"
        );

        # Verify user 1 cannot see user 2's node (cross-user isolation)
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "other_root_access.jac"),
            entrypoint="check_node",
            args=[],
            **{"root": user1_root},
            nd=user2_node
        );
        cross_access = capture_get(captured).strip();
        assert cross_access == "" , (
            f"User 1 should NOT see user 2 node, but got: {cross_access}"
        );

        # Verify user 2 cannot see user 1's node
        captured = capture_start();
        execution.enter(
            filename=os.path.join(FIXTURES, "other_root_access.jac"),
            entrypoint="check_node",
            args=[],
            **{"root": user2_root},
            nd=user1_node
        );
        cross_access = capture_get(captured).strip();
        assert cross_access == "" , (
            f"User 2 should NOT see user 1 node, but got: {cross_access}"
        );
    } finally {
        Jac.set_base_path(_orig_base);
        shutil.rmtree(_tmpdir, ignore_errors=True);
    }
}
