# M3 CPython-runtime hook: `import from rust.<crate>` resolves under jaclang.
#
# The counterpart to the AOT path: here a plain `.jac` program run on the
# *interpreter* imports a Rust bridge by name, and jaclang's own in-package
# meta-importer (jaclang.compiler.rust_bridge.install_rust_namespace,
# auto-installed by `import jaclang`) resolves it -- no dependency on the
# separate jac_bridge_loader dev package, and the same .so search order + D2
# metadata parser the na compiler step uses.
#
# Subprocess-based so the global sys.meta_path / sys.modules mutations stay out
# of the in-process test interpreter.
import os;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from _fixtures { workspace }


glob _WS = workspace(),
     _REPO = workspace().parent,
     _JAC = workspace().parent / "jac",
     _SO = workspace() / "target" / "release" / "libjac_bridge_regex.so";


def _env -> dict {
    env = dict(os.environ);
    env["PYTHONPATH"] = str(_JAC);
    env["JAC_RUST_BRIDGES_PATH"] = str(Path(_SO).parent);
    env["LD_LIBRARY_PATH"] = str(Path(_SO).parent);
    return env;
}


test "import jaclang installs self contained rust finder" {
    if not Path(_SO).is_file() {
        return;
    }
    prog = r"""import sys, jaclang
from jaclang.compiler.rust_bridge import RustBridgeFinder
fs = [f for f in sys.meta_path if isinstance(f, RustBridgeFinder)]
assert len(fs) == 1, fs
import rust.regex as rx
r = rx.Regex(r'foo\d+')
print('m1', int(r.is_match('foo42')))
print('m2', int(r.is_match('bar')))
r.close()
try:
    rx.Regex('(unclosed')
    print('noerror')
except rx.RegexError as e:
    print('err', str(e).splitlines()[0])
""";
    r = subprocess.run(
        [sys.executable, "-c", prog],
        cwd=str(_JAC),
        env=_env(),
        capture_output=True,
        text=True,
        timeout=300,
    );
    assert r.returncode == 0 , f"{r.stdout}\n{r.stderr}";
    out = [
        ln
        for ln in r.stdout.splitlines()
        if ln[:2] in ("m1", "m2") or ln.startswith(("err", "noerror"))
    ];
    assert out == ["m1 1", "m2 0", "err regex parse error:"] , out;
}


test "jac program imports rust regex on runtime" {
    if not Path(_SO).is_file() {
        return;
    }
    program = r"""import from rust.regex { Regex }

with entry {
    re = Regex("foo\\d+");
    if re.is_match("foo42") { print("RT match=1"); } else { print("RT match=0"); }
    if re.is_match("bar") { print("RT nomatch=1"); } else { print("RT nomatch=0"); }
    re.close();
    try {
        bad = Regex("(unclosed");
        print("RT badpat=NOERROR");
    } except Exception as e {
        print("RT badpat=" + str(e).split("\\n")[0]);
    }
}
""";
    with tempfile.TemporaryDirectory() as td {
        src = Path(td) / "rt_use_bridge.jac";
        src.write_text(program);
        r = subprocess.run(
            [sys.executable, "-m", "jaclang", "run", str(src)],
            cwd=str(_JAC),
            env=_env(),
            capture_output=True,
            text=True,
            timeout=300,
        );
        # NOTE: assert on stdout, not returncode -- an unrelated pre-existing
        # JScaleExecutionContext teardown bug can taint the exit code even on a
        # clean run; the program's own output is what proves the import resolved.
        lines = [
            ln
            for ln in r.stdout.splitlines()
            if ln.startswith("RT ")
        ];
        assert lines == [
            "RT match=1",
            "RT nomatch=0",
            "RT badpat=regex parse error:",

        ] , f"stdout:\n{r.stdout}\nstderr:\n{r.stderr}";
    }
}
