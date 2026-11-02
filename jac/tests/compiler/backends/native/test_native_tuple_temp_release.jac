"""A tuple a call returns, indexed at once (`pair(i)[1]`), is released.

Reading a field of a temporary heap tuple took the field but never released
the tuple, so the tuple and everything it held stayed allocated: 128 bytes a
call with an object inside, 192 with a string. The fixture indexes three
million fresh tuples in each form; peak RSS has to stay flat instead of
growing by about 370 MB and 560 MB."""

import from tests.support { jac_command }
import os;
import re;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }

glob FIXTURE = str(
         Path(__file__).resolve().parent / "fixtures" / "tuple_temp_release.jac"
     ),
     _BIN: list[str] = [];

def _binary -> str {
    if _BIN {
        return _BIN[0];
    }
    out = os.path.join(tempfile.mkdtemp(), "tuple_temp_release");
    comp = subprocess.run(
        jac_command("build", "--native", FIXTURE, "-o", out),
        capture_output=True,
        text=True,
        timeout=300
    );
    assert comp.returncode == 0 , comp.stderr[-800:];
    _BIN.append(out);
    return out;
}

"""Peak RSS in MB and stdout of one run in `mode`."""
def _run(mode: str) -> tuple[int, str] {
    env = os.environ.copy();
    env["LC_ALL"] = "C";
    darwin = sys.platform == "darwin";
    proc = subprocess.run(
        ["/usr/bin/time", "-l" if darwin else "-v", _binary(), mode, "3000000"],
        capture_output=True,
        text=True,
        timeout=120,
        env=env
    );
    assert proc.returncode == 0 , proc.stderr[-800:];
    if darwin {
        m = re.search(r"(\d+)\s+maximum resident set size", proc.stderr);
        rss = int(m.group(1)) // (1024 * 1024) if m else -1;
    } else {
        m = re.search(r"Maximum resident set size \(kbytes\):\s*(\d+)", proc.stderr);
        rss = int(m.group(1)) // 1024 if m else -1;
    }
    return (rss, proc.stdout.strip());
}

test "a returned tuple holding an object is released after its field is read" {
    (rss, out) = _run("obj");
    assert out == "4499998500000" , out;
    assert 0 <= rss < 40 , f"peak RSS {rss} MB";
}

test "a returned tuple holding a string is released after its field is read" {
    (rss, out) = _run("str");
    assert out == "8999997000000" , out;
    assert 0 <= rss < 40 , f"peak RSS {rss} MB";
}
