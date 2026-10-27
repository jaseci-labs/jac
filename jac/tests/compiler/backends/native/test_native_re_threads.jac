import os;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support { assert_native_identity, jac_command }

def fixture(name: str) -> str {
    return str(Path(__file__).resolve().parent / "fixtures" / name);
}

"""re's compiled-pattern cache is shared by every thread, and so is each
compiled Pattern's scratch state. flow workers compiling past the cache size,
purging it, and searching one shared Pattern must each get their own answers."""
test "flow workers share the re cache and a compiled pattern safely" {
    out = assert_native_identity(
        fixture("re_flow_threads.jac"), profiles=["rc", "managed"]
    );
    assert out == "bad 0\n" , out;
}


"""A plain project's `jac run` checks `re.finditer` against CPython's stub, an
iterator, while the native `re` runs it, so the native one must hand back an
iterator too: the run used to crash on the first step (#10373). The fixture is
copied out of this directory first, because its jac.toml pins placements."""
test "jac run steps re.finditer as an iterator, as CPython does" {
    work = os.path.realpath(tempfile.mkdtemp(prefix="jac_finditer_"));
    try {
        shutil.copy(fixture("re_finditer_iter.jac"), work);
        proc = subprocess.run(
            jac_command("run", os.path.join(work, "re_finditer_iter.jac")),
            cwd=work,
            capture_output=True,
            text=True,
            timeout=900
        );
    } finally {
        shutil.rmtree(work, ignore_errors=True);
    }
    assert proc.returncode == 0 , f"exit {proc.returncode}: {proc.stderr[-400:]}";
    assert proc.stdout.splitlines()[-1] == "[1, 5] 4 3 0 [0, 2, 2, 5]" , proc.stdout;
}
