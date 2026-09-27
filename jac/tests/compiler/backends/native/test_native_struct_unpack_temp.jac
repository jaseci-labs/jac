"""`struct.unpack(fmt, data[a:b])` released neither the temporary slice nor a
temporary bytearray it was handed, so a binary parser reading each field
from a fresh slice leaked one buffer per field (about 48 bytes a call).
The fixture unpacks three million temporaries in each form; peak RSS has to
stay flat instead of growing by ~150 MB."""

import from tests.support { jac_command }
import os;
import re;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }

glob FIXTURE = str(
         Path(__file__).resolve().parent / "fixtures" / "struct_unpack_temp_buffer.jac"
     ),
     _BIN: list[str] = [];

def _binary -> str {
    if _BIN {
        return _BIN[0];
    }
    out = os.path.join(tempfile.mkdtemp(), "struct_unpack_temp");
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
    env["MODE"] = mode;
    darwin = sys.platform == "darwin";
    proc = subprocess.run(
        ["/usr/bin/time", "-l" if darwin else "-v", _binary()],
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

test "unpack releases a temporary slice" {
    (rss, out) = _run("u16");
    assert out == "u16 1539000000" , out;
    assert 0 <= rss < 40 , f"peak RSS {rss} MB";
}

test "unpack of a float releases a temporary slice" {
    (rss, out) = _run("f32");
    assert out == "f32 3000000" , out;
    assert 0 <= rss < 40 , f"peak RSS {rss} MB";
}

test "unpack_from releases a temporary slice" {
    (rss, out) = _run("from");
    assert out == "from 3081000000" , out;
    assert 0 <= rss < 40 , f"peak RSS {rss} MB";
}

test "unpack releases a temporary bytearray" {
    (rss, out) = _run("bytearray");
    assert out == "bytearray 1539000000" , out;
    assert 0 <= rss < 40 , f"peak RSS {rss} MB";
}
