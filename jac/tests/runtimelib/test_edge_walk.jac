"""Tests for edge-filtered walker traversal with persistence across runs.

Verifies that a graph built in one `jac run` invocation persists correctly
and can be walked with edge-type filtering in a subsequent invocation.
"""

import os;
import shutil;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import jaclang;

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     FIXTURES = os.path.join(JAC_ROOT, "tests", "runtimelib", "fixtures");

test "edge filtered walk persists across runs" {
    with tempfile.TemporaryDirectory() as tmpdir {
        # Set up a project directory with jac.toml (enables persistence).
        jac_toml = os.path.join(tmpdir, "jac.toml");
        with open(jac_toml, "w") as f {
            f.write("[project]\nname = \"test_edge_walk\"\n");
        }
        # Copy the fixture into the temp project.
        src = os.path.join(FIXTURES, "edge_walk_fixture.jac");
        dst = os.path.join(tmpdir, "edge_walk_fixture.jac");
        shutil.copy2(src, dst);
        # 1. Clean the DB.
        clean_result = subprocess.run(
            [sys.executable, "-m", "jaclang", "clean", "--force"],
            capture_output=True,
            text=True,
            cwd=tmpdir
        );
        assert clean_result.returncode == 0 , (
            f"jac clean failed:\nstdout: {clean_result.stdout}\nstderr: {clean_result.stderr}"
        );
        # 2. Run PHASE=0 — build the graph.
        env = os.environ.copy();
        env["PHASE"] = "0";
        phase0_result = subprocess.run(
            [sys.executable, "-m", "jaclang", "run", "edge_walk_fixture.jac"],
            capture_output=True,
            text=True,
            cwd=tmpdir,
            env=env
        );
        assert phase0_result.returncode == 0 , (
            f"PHASE=0 failed:\nstdout: {phase0_result.stdout}\nstderr: {phase0_result.stderr}"
        );
        assert "PHASE 0: Tree created" in phase0_result.stdout;
        # 3. Run PHASE=1 — walk the persisted graph via Link edges only.
        env["PHASE"] = "1";
        phase1_result = subprocess.run(
            [sys.executable, "-m", "jaclang", "run", "edge_walk_fixture.jac"],
            capture_output=True,
            text=True,
            cwd=tmpdir,
            env=env
        );
        assert phase1_result.returncode == 0 , (
            f"PHASE=1 failed:\nstdout: {phase1_result.stdout}\nstderr: {phase1_result.stderr}"
        );
        assert "PHASE 1: Walker visited (Link edges only):" in phase1_result.stdout;
        assert "TypeA(1)" in phase1_result.stdout;
        assert "TypeA(2)" in phase1_result.stdout;
    }
}
