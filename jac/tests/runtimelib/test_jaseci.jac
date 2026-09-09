"""Test for jaseci plugin."""

import io;
import os;
import sys;
import shutil;
import from tests.support { JAC_ROOT }
import from tempfile { mkdtemp }
import jaclang;
import from jaclang { JacRuntime as Jac }
import from jaclang.cli.commands { execution }
import from tests.support { get_object }

glob FIXTURES = os.path.join(JAC_ROOT, "tests", "runtimelib", "fixtures");

def _as_any(v: any) -> any {
    return v;
}

def capture_start -> io.StringIO {
    captured = io.StringIO();
    sys.stdout = captured;
    return captured;
}

def capture_get(captured: io.StringIO) -> str {
    sys.stdout = sys.__stdout__;
    return captured.getvalue();
}

"""Test different access validation."""
def trigger_access_validation_test(
    roots: list, nodes: list, give_access_to_full_graph: bool, via_all: bool = False
) {
    captured = capture_start();

    ##############################################
    #              ALLOW READ ACCESS             #
    ##############################################
    node_1 = "" if give_access_to_full_graph else nodes[0];
    node_2 = "" if give_access_to_full_graph else nodes[1];

    execution.run(
        target=os.path.join(FIXTURES, "other_root_access.jac"),
        entry_name="allow_other_root_access",
        args=_as_any([roots[1], 0, via_all]),
        root_id=roots[0],
        nd=node_1
    );
    execution.run(
        target=os.path.join(FIXTURES, "other_root_access.jac"),
        entry_name="allow_other_root_access",
        args=_as_any([roots[0], 0, via_all]),
        root_id=roots[1],
        nd=node_2
    );

    execution.run(
        target=os.path.join(FIXTURES, "other_root_access.jac"),
        entry_name="update_node",
        args=_as_any([20]),
        root_id=roots[0],
        nd=nodes[1]
    );
    execution.run(
        target=os.path.join(FIXTURES, "other_root_access.jac"),
        entry_name="update_node",
        args=_as_any([10]),
        root_id=roots[1],
        nd=nodes[0]
    );

    execution.run(
        target=os.path.join(FIXTURES, "other_root_access.jac"),
        entry_name="update_target_node",
        args=_as_any([20, nodes[1]]),
        root_id=roots[0]
    );

    execution.run(
        target=os.path.join(FIXTURES, "other_root_access.jac"),
        entry_name="update_target_node",
        args=_as_any([10, nodes[0]]),
        root_id=roots[1]
    );

    execution.run(
        target=os.path.join(FIXTURES, "other_root_access.jac"),
        entry_name="check_node",
        args=[],
        root_id=roots[0],
        nd=nodes[1]
    );
    execution.run(
        target=os.path.join(FIXTURES, "other_root_access.jac"),
        entry_name="check_node",
        args=[],
        root_id=roots[1],
        nd=nodes[0]
    );
    archs = capture_get(captured).strip().split("\n");
    assert len(archs) == 2;

    # --------- NO UPDATE SHOULD HAPPEN -------- #
    assert archs[0] == "A(val=2)";
    assert archs[1] == "A(val=1)";

    # ---------- DISALLOW READ ACCESS ---------- #
    captured = capture_start();
    execution.run(
        target=os.path.join(FIXTURES, "other_root_access.jac"),
        entry_name="disallow_other_root_access",
        args=_as_any([roots[1], via_all]),
        root_id=roots[0],
        nd=node_1
    );
    execution.run(
        target=os.path.join(FIXTURES, "other_root_access.jac"),
        entry_name="disallow_other_root_access",
        args=_as_any([roots[0], via_all]),
        root_id=roots[1],
        nd=node_2
    );

    execution.run(
        target=os.path.join(FIXTURES, "other_root_access.jac"),
        entry_name="check_node",
        args=[],
        root_id=roots[0],
        nd=nodes[1]
    );
    execution.run(
        target=os.path.join(FIXTURES, "other_root_access.jac"),
        entry_name="check_node",
        args=[],
        root_id=roots[1],
        nd=nodes[0]
    );
    assert not capture_get(captured).strip();

    ##############################################
    #             ALLOW WRITE ACCESS             #
    ##############################################
    captured = capture_start();
    execution.run(
        target=os.path.join(FIXTURES, "other_root_access.jac"),
        entry_name="allow_other_root_access",
        args=_as_any([roots[1], "WRITE", via_all]),
        root_id=roots[0],
        nd=node_1
    );
    execution.run(
        target=os.path.join(FIXTURES, "other_root_access.jac"),
        entry_name="allow_other_root_access",
        args=_as_any([roots[0], "WRITE", via_all]),
        root_id=roots[1],
        nd=node_2
    );

    execution.run(
        target=os.path.join(FIXTURES, "other_root_access.jac"),
        entry_name="update_node",
        args=_as_any([200]),
        root_id=roots[0],
        nd=nodes[1]
    );
    execution.run(
        target=os.path.join(FIXTURES, "other_root_access.jac"),
        entry_name="update_node",
        args=_as_any([100]),
        root_id=roots[1],
        nd=nodes[0]
    );

    execution.run(
        target=os.path.join(FIXTURES, "other_root_access.jac"),
        entry_name="check_node",
        args=[],
        root_id=roots[0],
        nd=nodes[1]
    );
    execution.run(
        target=os.path.join(FIXTURES, "other_root_access.jac"),
        entry_name="check_node",
        args=[],
        root_id=roots[1],
        nd=nodes[0]
    );
    archs = capture_get(captured).strip().split("\n");
    assert len(archs) == 2;

    # ---------- UPDATE SHOULD HAPPEN ---------- #
    assert archs[0] == "A(val=200)";
    assert archs[1] == "A(val=100)";

    # ---------- DISALLOW WRITE ACCESS --------- #
    captured = capture_start();
    execution.run(
        target=os.path.join(FIXTURES, "other_root_access.jac"),
        entry_name="disallow_other_root_access",
        args=_as_any([roots[1], via_all]),
        root_id=roots[0],
        nd=node_1
    );
    execution.run(
        target=os.path.join(FIXTURES, "other_root_access.jac"),
        entry_name="disallow_other_root_access",
        args=_as_any([roots[0], via_all]),
        root_id=roots[1],
        nd=node_2
    );

    execution.run(
        target=os.path.join(FIXTURES, "other_root_access.jac"),
        entry_name="check_node",
        args=[],
        root_id=roots[0],
        nd=nodes[1]
    );
    execution.run(
        target=os.path.join(FIXTURES, "other_root_access.jac"),
        entry_name="check_node",
        args=[],
        root_id=roots[1],
        nd=nodes[0]
    );
    assert not capture_get(captured).strip();

    # ---------- ROOTS RESET OWN NODE ---------- #
    captured = capture_start();

    execution.run(
        target=os.path.join(FIXTURES, "other_root_access.jac"),
        entry_name="update_node",
        args=_as_any([1]),
        root_id=roots[0],
        nd=nodes[0]
    );
    execution.run(
        target=os.path.join(FIXTURES, "other_root_access.jac"),
        entry_name="update_node",
        args=_as_any([2]),
        root_id=roots[1],
        nd=nodes[1]
    );
    capture_get(captured);
}

test "walker simple persistent" {
    _tmpdir = mkdtemp();
    _orig_base = Jac.get_base_path_dir();
    Jac.set_base_path(_tmpdir);
    try {
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "simple_persistent.jac"),
            entry_name="create",
            args=[]
        );
        execution.run(
            target=os.path.join(FIXTURES, "simple_persistent.jac"),
            entry_name="traverse",
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
    _orig_base = Jac.get_base_path_dir();
    Jac.set_base_path(_tmpdir);
    try {
        execution.run(
            target=os.path.join(FIXTURES, "simple_persistent.jac"),
            entry_name="create",
            args=[]
        );
        root_obj = get_object(
            filename=os.path.join(FIXTURES, "simple_persistent.jac"), id="root"
        );
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "simple_persistent.jac"),
            entry_name="traverse",
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
    _orig_base = Jac.get_base_path_dir();
    Jac.set_base_path(_tmpdir);
    try {
        execution.run(
            target=os.path.join(FIXTURES, "simple_persistent.jac"),
            entry_name="create",
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
        execution.run(
            target=os.path.join(FIXTURES, "simple_persistent.jac"),
            entry_name="traverse",
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
    _orig_base = Jac.get_base_path_dir();
    Jac.set_base_path(_tmpdir);
    try {
        execution.run(target=os.path.join(FIXTURES, "simple_node_connection.jac"));
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
        assert {no["archetype"].tag for no in node_objs} == {"first", "second"};
    } finally {
        Jac.set_base_path(_orig_base);
        shutil.rmtree(_tmpdir, ignore_errors=True);
    }
}

test "filter on edge get edge" {
    _tmpdir = mkdtemp();
    _orig_base = Jac.get_base_path_dir();
    Jac.set_base_path(_tmpdir);
    try {
        execution.run(target=os.path.join(FIXTURES, "simple_node_connection.jac"));
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "simple_node_connection.jac"),
            entry_name="filter_on_edge_get_edge",
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
    _orig_base = Jac.get_base_path_dir();
    Jac.set_base_path(_tmpdir);
    try {
        execution.run(target=os.path.join(FIXTURES, "simple_node_connection.jac"));
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "simple_node_connection.jac"),
            entry_name="filter_on_edge_get_node",
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
    _orig_base = Jac.get_base_path_dir();
    Jac.set_base_path(_tmpdir);
    try {
        execution.run(target=os.path.join(FIXTURES, "simple_node_connection.jac"));
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "simple_node_connection.jac"),
            entry_name="filter_on_node_get_node",
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
    _orig_base = Jac.get_base_path_dir();
    Jac.set_base_path(_tmpdir);
    try {
        execution.run(target=os.path.join(FIXTURES, "simple_node_connection.jac"));
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "simple_node_connection.jac"),
            entry_name="filter_on_edge_visit",
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
    _orig_base = Jac.get_base_path_dir();
    Jac.set_base_path(_tmpdir);
    try {
        execution.run(target=os.path.join(FIXTURES, "simple_node_connection.jac"));
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "simple_node_connection.jac"),
            entry_name="filter_on_node_visit",
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
    _orig_base = Jac.get_base_path_dir();
    Jac.set_base_path(_tmpdir);
    try {
        execution.run(
            target=os.path.join(FIXTURES, "simple_persistent.jac"),
            entry_name="create",
            args=[]
        );
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "simple_persistent.jac"),
            entry_name="indirect_ref",
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
    _orig_base = Jac.get_base_path_dir();
    Jac.set_base_path(_tmpdir);
    try {
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "graph_purger.jac"),
            entry_name="populate",
            args=[]
        );
        execution.run(
            target=os.path.join(FIXTURES, "graph_purger.jac"),
            entry_name="traverse",
            args=[]
        );
        execution.run(
            target=os.path.join(FIXTURES, "graph_purger.jac"),
            entry_name="check",
            args=[]
        );
        execution.run(
            target=os.path.join(FIXTURES, "graph_purger.jac"),
            entry_name="purge",
            args=[]
        );
        output = capture_get(captured).strip();
        assert output
            == (
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
            ) , f"got: {output!r}";
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "graph_purger.jac"),
            entry_name="traverse",
            args=[]
        );
        execution.run(
            target=os.path.join(FIXTURES, "graph_purger.jac"),
            entry_name="check",
            args=[]
        );
        execution.run(
            target=os.path.join(FIXTURES, "graph_purger.jac"),
            entry_name="purge",
            args=[]
        );
        output = capture_get(captured).strip();
        assert output == "Root()\n1\n0" , f"got: {output!r}";
    } finally {
        Jac.set_base_path(_orig_base);
        shutil.rmtree(_tmpdir, ignore_errors=True);
    }
}

test "other root access" {
    _tmpdir = mkdtemp();
    _orig_base = Jac.get_base_path_dir();
    Jac.set_base_path(_tmpdir);
    try {
        ##############################################
        #                CREATE ROOTS                #
        ##############################################
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "other_root_access.jac"),
            entry_name="create_other_root",
            args=[]
        );
        root1 = capture_get(captured).strip();

        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "other_root_access.jac"),
            entry_name="create_other_root",
            args=[]
        );
        root2 = capture_get(captured).strip();

        ##############################################
        #           CREATE RESPECTIVE NODES          #
        ##############################################
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "other_root_access.jac"),
            entry_name="create_node",
            args=_as_any([1]),
            root_id=root1
        );
        execution.run(
            target=os.path.join(FIXTURES, "other_root_access.jac"),
            entry_name="create_node",
            args=_as_any([2]),
            root_id=root2
        );
        nodes = capture_get(captured).strip().split("\n");
        assert len(nodes) == 2;

        ##############################################
        #           VISIT RESPECTIVE NODES           #
        ##############################################
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "other_root_access.jac"),
            entry_name="check_node",
            args=[],
            root_id=root1
        );
        execution.run(
            target=os.path.join(FIXTURES, "other_root_access.jac"),
            entry_name="check_node",
            args=[],
            root_id=root2
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
        execution.run(
            target=os.path.join(FIXTURES, "other_root_access.jac"),
            entry_name="check_node",
            args=[],
            root_id=root1,
            nd=nodes[1]
        );
        execution.run(
            target=os.path.join(FIXTURES, "other_root_access.jac"),
            entry_name="check_node",
            args=[],
            root_id=root2,
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

test "get object read access" {
    _tmpdir = mkdtemp();
    _orig_base = Jac.get_base_path_dir();
    Jac.set_base_path(_tmpdir);
    try {
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "other_root_access.jac"),
            entry_name="create_other_root",
            args=[]
        );
        root1 = capture_get(captured).strip();

        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "other_root_access.jac"),
            entry_name="create_other_root",
            args=[]
        );
        root2 = capture_get(captured).strip();

        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "other_root_access.jac"),
            entry_name="create_node",
            args=_as_any([1]),
            root_id=root1
        );
        node_id = capture_get(captured).strip();

        # ---------- OWNER READS OWN NODE ---------- #
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "other_root_access.jac"),
            entry_name="read_target_node",
            args=[node_id],
            root_id=root1
        );
        assert capture_get(captured).strip() == "A(val=1)";

        # ------- OTHER ROOT DENIED BY-ID READ ----- #
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "other_root_access.jac"),
            entry_name="read_target_node",
            args=[node_id],
            root_id=root2
        );
        assert capture_get(captured).strip() == "None";

        # -------- GRANT READ, THEN READABLE ------- #
        execution.run(
            target=os.path.join(FIXTURES, "other_root_access.jac"),
            entry_name="allow_other_root_access",
            args=_as_any([root2, 0]),
            root_id=root1,
            nd=node_id
        );
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "other_root_access.jac"),
            entry_name="read_target_node",
            args=[node_id],
            root_id=root2
        );
        assert capture_get(captured).strip() == "A(val=1)";

        # ------- REVOKE, DENIED AGAIN ------------- #
        execution.run(
            target=os.path.join(FIXTURES, "other_root_access.jac"),
            entry_name="disallow_other_root_access",
            args=[root2],
            root_id=root1,
            nd=node_id
        );
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "other_root_access.jac"),
            entry_name="read_target_node",
            args=[node_id],
            root_id=root2
        );
        assert capture_get(captured).strip() == "None";
    } finally {
        Jac.set_base_path(_orig_base);
        shutil.rmtree(_tmpdir, ignore_errors=True);
    }
}

test "savable object" {
    _tmpdir = mkdtemp();
    _orig_base = Jac.get_base_path_dir();
    Jac.set_base_path(_tmpdir);
    try {
        captured = capture_start();

        execution.run(
            target=os.path.join(FIXTURES, "savable_object.jac"),
            entry_name="create_custom_object",
            args=[]
        );

        prints = capture_get(captured).strip().split("\n");
        id = prints[0];

        assert prints[1]
            == (
                "SavableObject(val=0, arr=[], json={}, parent=Parent(val=1, arr=[1], json"
                "={'a': 1}, enum_field=<Enum.B: 'b'>, child=Child(val=2, arr=[1, 2], json"
                "={'a': 1, 'b': 2}, enum_field=<Enum.C: 'c'>)), enum_field=<Enum.A: 'a'>)"
            ) , f"create printed: {prints!r}";

        captured = capture_start();

        execution.run(
            target=os.path.join(FIXTURES, "savable_object.jac"),
            entry_name="get_custom_object",
            args=[id]
        );
        got = capture_get(captured).strip();
        expected = (
            "SavableObject(val=0, arr=[], json={}, parent=Parent(val=1, arr=[1], json"
            "={'a': 1}, enum_field=<Enum.B: 'b'>, child=Child(val=2, arr=[1, 2], json"
            "={'a': 1, 'b': 2}, enum_field=<Enum.C: 'c'>)), enum_field=<Enum.A: 'a'>)"
        );
        diag = "";
        if got != expected {
            import from jaclang.data.serializer { Serializer }
            import from jaclang.runtime { typecache }
            reg_cls = Serializer._registry.get("__main__.SavableObject");
            cached = typecache._cache.get(reg_cls) if reg_cls else None;
            resolved = typecache.get_field_types(reg_cls) if reg_cls else None;
            diag = (
                f" | main={sys.modules.get('__main__')!r}"
                f" | reg_cls={reg_cls!r}"
                f" | ann={reg_cls?.__annotations__!r}"
                f" | cached={cached!r}"
                f" | ft={resolved!r}"
            );
        }
        assert got == expected , f"reload printed: {got!r}{diag}";

        captured = capture_start();

        execution.run(
            target=os.path.join(FIXTURES, "savable_object.jac"),
            entry_name="update_custom_object",
            args=[id]
        );

        got = capture_get(captured).strip();
        assert got
            == (
                "SavableObject(val=1, arr=[1], json={'a': 1}, parent=Parent(val=2, arr=[1, 2], json"
                "={'a': 1, 'b': 2}, enum_field=<Enum.C: 'c'>, child=Child(val=3, arr=[1, 2, 3], json"
                "={'a': 1, 'b': 2, 'c': 3}, enum_field=<Enum.A: 'a'>)), enum_field=<Enum.B: 'b'>)"
            ) , f"update printed: {got!r}";

        captured = capture_start();

        execution.run(
            target=os.path.join(FIXTURES, "savable_object.jac"),
            entry_name="delete_custom_object",
            args=[id]
        );

        execution.run(
            target=os.path.join(FIXTURES, "savable_object.jac"),
            entry_name="get_custom_object",
            args=[id]
        );
        got = capture_get(captured).strip();
        assert got == "None" , f"post-delete get printed: {got!r}";
    } finally {
        Jac.set_base_path(_orig_base);
        shutil.rmtree(_tmpdir, ignore_errors=True);
    }
}

test "traversing save" {
    _tmpdir = mkdtemp();
    _orig_base = Jac.get_base_path_dir();
    Jac.set_base_path(_tmpdir);
    try {
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "traversing_save.jac"),
            entry_name="build",
            args=[]
        );

        execution.run(
            target=os.path.join(FIXTURES, "traversing_save.jac"),
            entry_name="view",
            args=[]
        );

        assert capture_get(captured).strip()
            == (
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
    _orig_base = Jac.get_base_path_dir();
    Jac.set_base_path(_tmpdir);
    try {
        ##############################################
        #              CREATE OTHER ROOT             #
        ##############################################
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "custom_access_validation.jac"),
            entry_name="create_other_root",
            args=[]
        );

        other_root = capture_get(captured).strip();

        ##############################################
        #                 CREATE NODE                #
        ##############################################
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "custom_access_validation.jac"),
            entry_name="create",
            args=[]
        );
        nd_str = capture_get(captured).strip();

        ##############################################
        #                 CHECK NODE                 #
        ##############################################

        # BY OWNER
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "custom_access_validation.jac"),
            entry_name="check",
            args=[],
            nd=nd_str
        );

        assert capture_get(captured).strip() == "A(val1='NO_ACCESS', val2=0)";

        # BY OTHER
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "custom_access_validation.jac"),
            entry_name="check",
            args=[],
            root_id=other_root,
            nd=nd_str
        );

        assert capture_get(captured).strip() == "";

        ##############################################
        #       UPDATE NODE (GIVE READ ACCESS)       #
        ##############################################

        # UPDATE BY OWNER
        execution.run(
            target=os.path.join(FIXTURES, "custom_access_validation.jac"),
            entry_name="update",
            args=_as_any(["READ", None]),
            nd=nd_str
        );

        # CHECK BY OTHER
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "custom_access_validation.jac"),
            entry_name="check",
            args=[],
            root_id=other_root,
            nd=nd_str
        );

        assert capture_get(captured).strip() == "A(val1='READ', val2=0)";

        ##############################################
        #     UPDATE NODE (BUT STILL READ ACCESS)    #
        ##############################################

        # UPDATE BY OTHER
        execution.run(
            target=os.path.join(FIXTURES, "custom_access_validation.jac"),
            entry_name="update",
            args=_as_any([None, 1]),
            root_id=other_root,
            nd=nd_str
        );

        # CHECK BY OTHER
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "custom_access_validation.jac"),
            entry_name="check",
            args=[],
            root_id=other_root,
            nd=nd_str
        );

        assert capture_get(captured).strip() == "A(val1='READ', val2=0)";

        ##############################################
        #       UPDATE NODE (GIVE WRITE ACCESS)      #
        ##############################################

        # UPDATE BY OWNER
        execution.run(
            target=os.path.join(FIXTURES, "custom_access_validation.jac"),
            entry_name="update",
            args=_as_any(["WRITE", None]),
            nd=nd_str
        );

        # UPDATE BY OTHER
        execution.run(
            target=os.path.join(FIXTURES, "custom_access_validation.jac"),
            entry_name="update",
            args=_as_any([None, 2]),
            root_id=other_root,
            nd=nd_str
        );

        # CHECK BY OTHER
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "custom_access_validation.jac"),
            entry_name="check",
            args=[],
            root_id=other_root,
            nd=nd_str
        );

        assert capture_get(captured).strip() == "A(val1='WRITE', val2=2)";

        ##############################################
        #         UPDATE NODE (REMOVE ACCESS)        #
        ##############################################

        # UPDATE BY OWNER
        execution.run(
            target=os.path.join(FIXTURES, "custom_access_validation.jac"),
            entry_name="update",
            args=_as_any(["NO_ACCESS", None]),
            nd=nd_str
        );

        # UPDATE BY OTHER
        execution.run(
            target=os.path.join(FIXTURES, "custom_access_validation.jac"),
            entry_name="update",
            args=_as_any([None, 5]),
            root_id=other_root,
            nd=nd_str
        );

        # CHECK BY OTHER
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "custom_access_validation.jac"),
            entry_name="check",
            args=[],
            root_id=other_root,
            nd=nd_str
        );

        assert capture_get(captured).strip() == "";

        # CHECK BY OWNER
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "custom_access_validation.jac"),
            entry_name="check",
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
    import json;
    import sqlite3;

    _tmpdir = mkdtemp();
    _orig_base = Jac.get_base_path_dir();
    Jac.set_base_path(_tmpdir);
    try {
        # The project's rows live in its database on the shared embedded
        # server; inspect them out-of-band through a fresh store connection.
        import from jaclang.data.pgembed { PgRuntime }
        import from jaclang.server.session { project_db_name, shared_pg_data_dir }
        import from jaclang.data.store { PgStore, TxnIsolation }

        def _db_counts -> tuple {
            rt = PgRuntime(
                data_dir=shared_pg_data_dir(),
                database=project_db_name(
                    _tmpdir, os.path.join(FIXTURES, "simple_node_connection.jac")
                )
            );
            st = PgStore(conninfo=rt.ensure());
            st.begin(TxnIsolation.READ_COMMITTED);
            rows = st.rows(
                "SELECT 1 FROM anchors WHERE id = CAST(:i AS uuid)",
                {'i': "00000000-0000-0000-0000-000000000000"}
            );
            assert rows , "Root should be persisted to database";
            edges = st.rows(
                """
                SELECT COUNT(*) FROM anchors
                WHERE src = CAST(:i AS uuid) OR dst = CAST(:i AS uuid)
                """,
                {'i': "00000000-0000-0000-0000-000000000000"}
            )[0][0];
            keys = st.rows("SELECT COUNT(*) FROM anchors", {})[0][0];
            st.commit();
            st.close();
            return (keys, edges);
        }

        ##############################################
        #          FIRST RUN - CREATE NODES          #
        ##############################################
        execution.run(target=os.path.join(FIXTURES, "simple_node_connection.jac"));

        (first_run_keys, first_run_edges) = _db_counts();

        # Should have root + 2 nodes + 2 edges = 5 keys
        assert first_run_keys > 1 , "First run should persist nodes to database";
        assert first_run_edges == 2 , "Root should have 2 edges after first run";

        ##############################################
        #    SECOND RUN - SHOULD REUSE, NOT          #
        #              RECREATE NODES                #
        ##############################################
        execution.run(target=os.path.join(FIXTURES, "simple_node_connection.jac"));

        (second_run_keys, second_run_edges) = _db_counts();

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
    _orig_base = Jac.get_base_path_dir();
    Jac.set_base_path(_tmpdir);
    try {
        # Create two separate user roots
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "other_root_access.jac"),
            entry_name="create_other_root",
            args=[]
        );
        user1_root = capture_get(captured).strip();

        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "other_root_access.jac"),
            entry_name="create_other_root",
            args=[]
        );
        user2_root = capture_get(captured).strip();

        # Verify different roots were created
        assert user1_root != user2_root , "Each user should have a unique root";

        # User 1 creates a node with val=100
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "other_root_access.jac"),
            entry_name="create_node",
            args=_as_any([100]),
            root_id=user1_root
        );
        user1_node = capture_get(captured).strip();

        # User 2 creates a node with val=200
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "other_root_access.jac"),
            entry_name="create_node",
            args=_as_any([200]),
            root_id=user2_root
        );
        user2_node = capture_get(captured).strip();

        # Verify user 1 can only see their own node (val=100)
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "other_root_access.jac"),
            entry_name="check_node",
            args=[],
            root_id=user1_root
        );
        user1_sees = capture_get(captured).strip();
        assert user1_sees == "A(val=100)" , (
            f"User 1 should see their node, got: {user1_sees}"
        );

        # Verify user 2 can only see their own node (val=200)
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "other_root_access.jac"),
            entry_name="check_node",
            args=[],
            root_id=user2_root
        );
        user2_sees = capture_get(captured).strip();
        assert user2_sees == "A(val=200)" , (
            f"User 2 should see their node, got: {user2_sees}"
        );

        # Verify user 1 cannot see user 2's node (cross-user isolation)
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "other_root_access.jac"),
            entry_name="check_node",
            args=[],
            root_id=user1_root,
            nd=user2_node
        );
        cross_access = capture_get(captured).strip();
        assert cross_access == "" , (
            f"User 1 should NOT see user 2 node, but got: {cross_access}"
        );

        # Verify user 2 cannot see user 1's node
        captured = capture_start();
        execution.run(
            target=os.path.join(FIXTURES, "other_root_access.jac"),
            entry_name="check_node",
            args=[],
            root_id=user2_root,
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
