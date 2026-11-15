"""A sort key that captures an object keeps it alive for the sort and lets it
go after, on every list length, including the empty and single-element lists
that skip the comparison loop. The fixture sorts lists of zero, one and two
cells many times, and an RC debug build dumps its live objects at exit, which
must hold no leak. The comparison against Python lives in
prim_sort_capture.jac."""
import os;
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support { jac_command }

glob FIXTURE = str(
         Path(__file__).resolve().parent / "fixtures" / "sort_key_closure_release.jac"
     );

test "sort keys capturing an object release it on every list length" {
    out_bin = os.path.join(tempfile.mkdtemp(), "probe.bin");
    comp = subprocess.run(
        jac_command("build", "--native", FIXTURE, "-o", out_bin, "--debug"),
        capture_output=True,
        text=True,
        timeout=900
    );
    assert comp.returncode == 0 , f"nacompile failed: {comp.stderr[-800:]
        if comp.stderr
        else '(empty)'}";
    proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=120);
    assert proc.returncode == 0 , f"binary failed: {proc.stderr[-400:]
        if proc.stderr
        else '(empty)'}";
    assert proc.stdout.split("\n")[0] == "60" , proc.stdout[-400:];
    assert "RC LIVE OBJECTS at exit" in proc.stdout , proc.stdout[-400:];
    leaks = [
        line
        for line in proc.stdout.split("\n")
        if "<- LEAK" in line
    ];
    assert not leaks , f"sort keys leaked: {len(leaks)} e.g. {leaks[:3]}";
}
