"""End-to-end tests for topology index using native Jac graph syntax.

Verifies correctness of the full pipeline: connect (+>) -> index update ->
query planning via edge ops (->) and filter comprehensions ([?:Type]) ->
correct results. Uses real Jac edge/filter syntax so regressions in the
compiler pipeline (exit_edge_ref_trailer, exit_filter_compr) are caught.
"""

import os;
import shutil;
import from tempfile { mkdtemp }
import from jaclang { JacRuntimeInterface as Jac }
import from jaclang.jac0core.runtime { JacRuntime }
import from jaclang.runtimelib.context { ExecutionContext }
import from jaclang.project.config { JacConfig, set_config }

node TypeA {
    has val: int = 0;
}

node TypeB {
    has val: int = 0;
}

edge EdgeX {}
edge EdgeY {}

test "index type-filtered query returns correct results" {
    tmpdir = mkdtemp();
    orig_base = JacRuntime.base_path_dir;
    try {
        cfg = JacConfig();
        cfg.run.topology_index = True;
        set_config(cfg);
        JacRuntime.set_base_path(tmpdir);
        ctx = ExecutionContext();
        JacRuntime.set_context(ctx);

        r = root;
        Jac.save(r);

        for i in range(10) {
            r +>: EdgeX :+> TypeA(val=i);
        }
        for i in range(90) {
            r +>: EdgeX :+> TypeB(val=i);
        }
        Jac.save(r);

        # Type-filtered: only TypeA via EdgeX
        result = [r->:EdgeX:->[?:TypeA]];
        assert len(result) == 10 , f"Expected 10 TypeA, got {len(result)}";
        assert sorted([n.val for n in result]) == list(range(10));

        # Unfiltered: all 100 nodes
        result_all = [r->:EdgeX:->];
        assert len(result_all) == 100 , f"Expected 100 total, got {len(result_all)}";

        ctx.close();
    } finally {
        JacRuntime.set_base_path(orig_base);
        set_config(JacConfig());
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

test "index results match non-indexed results in same context" {
    tmpdir = mkdtemp();
    orig_base = JacRuntime.base_path_dir;
    try {
        cfg = JacConfig();
        cfg.run.topology_index = True;
        set_config(cfg);
        JacRuntime.set_base_path(tmpdir);
        ctx = ExecutionContext();
        JacRuntime.set_context(ctx);

        r = root;
        Jac.save(r);
        for i in range(20) {
            r +>: EdgeX :+> TypeA(val=i);
        }
        for i in range(80) {
            r +>: EdgeX :+> TypeB(val=i);
        }
        Jac.save(r);

        # With index (default): type-filtered
        on_result = sorted([n.val for n in [r->:EdgeX:->[?:TypeA]]]);

        # Disable index and re-query in same context
        cfg.run.topology_index = False;
        set_config(cfg);
        off_result = sorted([n.val for n in [r->:EdgeX:->[?:TypeA]]]);

        assert off_result == on_result , f"Results differ: off={off_result} on={on_result}";
        assert len(off_result) == 20;

        ctx.close();
    } finally {
        JacRuntime.set_base_path(orig_base);
        set_config(JacConfig());
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

test "index returns empty for non-matching edge type" {
    tmpdir = mkdtemp();
    orig_base = JacRuntime.base_path_dir;
    try {
        cfg = JacConfig();
        cfg.run.topology_index = True;
        set_config(cfg);
        JacRuntime.set_base_path(tmpdir);
        ctx = ExecutionContext();
        JacRuntime.set_context(ctx);

        r = root;
        Jac.save(r);
        for i in range(10) {
            r +>: EdgeX :+> TypeA(val=i);
        }
        Jac.save(r);

        # EdgeY not in graph — should be empty
        result = [r->:EdgeY:->[?:TypeA]];
        assert len(result) == 0 , f"Expected 0, got {len(result)}";

        ctx.close();
    } finally {
        JacRuntime.set_base_path(orig_base);
        set_config(JacConfig());
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

test "index built on root with null root field" {
    tmpdir = mkdtemp();
    orig_base = JacRuntime.base_path_dir;
    try {
        cfg = JacConfig();
        cfg.run.topology_index = True;
        set_config(cfg);
        JacRuntime.set_base_path(tmpdir);
        ctx = ExecutionContext();
        JacRuntime.set_context(ctx);

        r = root;
        Jac.save(r);
        r +>: EdgeX :+> TypeA(val=42);
        Jac.save(r);

        idx = r.__jac__.get_topology_index();
        assert len(idx) > 0 , "Index should have edges";
        assert len(idx.node_table) == 2 , "Index should have root + TypeA";

        ctx.close();
    } finally {
        JacRuntime.set_base_path(orig_base);
        set_config(JacConfig());
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}
