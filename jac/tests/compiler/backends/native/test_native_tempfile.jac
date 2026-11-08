"""The native `tempfile.mkdtemp` must exclusively create mode-0700 dirs.

`mkdtemp` is a security boundary: it must detect a name collision through
mkdir(2)'s EEXIST and retry like CPython, propagate the real errno when the
target parent is unusable, and return an absolute path. Compile a probe
natively and check the directories it reports against the host filesystem.
"""

import os;
import stat;
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support { jac_command }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");

def build_probe -> str {
    src = os.path.join(FIXTURES, "tempfile_mkdtemp_probe.jac");
    out_bin = os.path.join(tempfile.mkdtemp(), "mkdtemp_probe");
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

test "mkdtemp returns a fresh mode-0700 absolute directory under TMPDIR" {
    probe = build_probe();
    tmp = Path(tempfile.mkdtemp());
    env = os.environ.copy();
    env["TMPDIR"] = str(tmp);
    # The probe takes its mode from argv[1]; "default" is the no-options call.
    runs = [
        subprocess.run(
            [probe, "default"], capture_output=True, text=True, timeout=120, env=env
        ) for _ in range(2)
    ];
    paths = [];
    for proc in runs {
        assert proc.returncode == 0 , proc.stderr;
        paths.append(Path(proc.stdout.strip()));
    }
    assert paths[0] != paths[1] , "mkdtemp must not reuse a directory";
    for p in paths {
        assert p.is_dir();
        assert p.is_absolute();
        assert p.parent == tmp;
        assert stat.S_IMODE(p.stat().st_mode) == 0o700 , "mkdtemp must create with mode 0700";
    }
}

test "mkdtemp honors prefix, suffix, and an explicit dir" {
    probe = build_probe();
    tmp = Path(tempfile.mkdtemp());
    env = os.environ.copy();
    env["TMPDIR"] = str(tmp);
    proc = subprocess.run(
        [probe, "affix"], capture_output=True, text=True, timeout=120, env=env
    );
    assert proc.returncode == 0 , proc.stderr;
    made = Path(proc.stdout.strip());
    assert made.parent == tmp and made.is_dir();
    assert made.name.startswith("jacp-") and made.name.endswith("-sfx") , made.name;
    base = tmp / "base";
    base.mkdir();
    proc = subprocess.run(
        [probe, "dir", str(base)], capture_output=True, text=True, timeout=120
    );
    assert proc.returncode == 0 , proc.stderr;
    made = Path(proc.stdout.strip());
    assert made.parent == base and made.is_dir();
}

test "mkdtemp under a relative dir still returns an absolute path" {
    probe = build_probe();
    tmp = Path(tempfile.mkdtemp());
    (tmp / "rel").mkdir();
    proc = subprocess.run(
        [probe, "dir", "rel"], capture_output=True, text=True, timeout=120, cwd=str(tmp)
    );
    assert proc.returncode == 0 , proc.stderr;
    made = Path(proc.stdout.strip());
    assert made.is_absolute();
    assert made.parent == (tmp / "rel").resolve();
}

test "mkdtemp on a missing dir reports the real errno on the first attempt" {
    probe = build_probe();
    tmp = Path(tempfile.mkdtemp());
    proc = subprocess.run(
        [probe, "missing", str(tmp / "no-such-dir")],
        capture_output=True,
        text=True,
        timeout=120
    );
    assert proc.returncode != 0;
    output = proc.stdout + proc.stderr;
    assert "unreachable" not in output;
    assert "No such file or directory" in output , f"the real errno must propagate, not a generic retry failure:\n{output}";
}
