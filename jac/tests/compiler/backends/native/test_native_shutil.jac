"""The native `shutil.rmtree` is best-effort on request and precise on failure.

The fused launcher prunes stale runtimes through the bundled `shutil`, which
had no `ignore_errors`, dropped `unlink`'s result, and raised on `rmdir`
naming the parent directory instead of the file that could not be removed
(#9053, #9060). Every `jac` invocation on a machine holding an undeletable
stale runtime died before running its command. Compile a probe natively and
drive it against a tree with an undeletable child.
"""

import os;
import stat;
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support { jac_command }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");

def build_probe -> str {
    src = os.path.join(FIXTURES, "shutil_rmtree_probe.jac");
    out_bin = os.path.join(tempfile.mkdtemp(), "rmtree_probe");
    comp = subprocess.run(
        jac_command("build", "--native", src, "-o", out_bin),
        capture_output=True,
        text=True,
        timeout=900
    );
    assert comp.returncode == 0 , "nacompile failed: "
        + (comp.stdout + comp.stderr)[-3000:];
    return out_bin;
}

"""A tree whose `stuck/inner/file` cannot be unlinked (its directory is read-only)."""
def locked_tree -> tuple[Path, Path] {
    base = Path(tempfile.mkdtemp()) / "tree";
    inner = base / "stuck" / "inner";
    inner.mkdir(parents=True);
    (inner / "file").write_bytes(b"x");
    (base / "free" / "sub").mkdir(parents=True);
    (base / "free" / "sub" / "file").write_bytes(b"y");
    (base / "loose").write_bytes(b"z");
    os.chmod(inner, stat.S_IRUSR | stat.S_IXUSR);
    return (base, inner);
}

def unlock(inner: Path) {
    os.chmod(inner, stat.S_IRWXU);
}

test "rmtree removes a tree and follows no symlink into a directory" {
    probe = build_probe();
    tmp = Path(tempfile.mkdtemp());
    tree = tmp / "tree";
    (tree / "a" / "b").mkdir(parents=True);
    (tree / "a" / "b" / "f").write_bytes(b"x");
    outside = tmp / "outside";
    outside.mkdir();
    (outside / "keep").write_bytes(b"k");
    os.symlink(outside, tree / "link");
    proc = subprocess.run(
        [probe, "strict", str(tree)], capture_output=True, text=True, timeout=120
    );
    assert proc.returncode == 0 , proc.stderr;
    assert "removed" in proc.stdout;
    assert not tree.exists();
    assert (outside / "keep").is_file() , "rmtree followed a symlink out of the tree";
}

test "rmtree with ignore_errors returns on an undeletable child and removes what it can" {
    if os.name != "posix" or os.geteuid() == 0 {
        return;
    }
    probe = build_probe();
    (base, inner) = locked_tree();
    try {
        proc = subprocess.run(
            [probe, "ignore", str(base)], capture_output=True, text=True, timeout=120
        );
    } finally {
        unlock(inner);
    }
    assert proc.returncode == 0 , f"a best-effort removal must not kill the process:\n{proc.stderr}";
    assert "returned" in proc.stdout;
    assert "exists" in proc.stdout , "the undeletable subtree cannot be gone";
    assert not (base / "free").exists() , "the deletable sibling must be removed";
    assert not (base / "loose").exists();
    assert (inner / "file").is_file();
}

test "rmtree without ignore_errors names the file it could not remove" {
    if os.name != "posix" or os.geteuid() == 0 {
        return;
    }
    probe = build_probe();
    (base, inner) = locked_tree();
    try {
        proc = subprocess.run(
            [probe, "strict", str(base)], capture_output=True, text=True, timeout=120
        );
    } finally {
        unlock(inner);
    }
    assert proc.returncode != 0;
    stuck = str(inner / "file");
    output = proc.stdout + proc.stderr;
    assert stuck in output , f"the error must name the file, not its parent:\n{output}";
    assert "removed" not in proc.stdout , "the probe must not report success";
}
