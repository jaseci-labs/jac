"""An f-string releases the strings it was handed for its pieces.

A piece whose value is a string made for the f-string (`{w[1:]}`,
`{w.upper()}`) was copied into the result and never released: about 63 bytes
a call. The fixture builds three million f-strings in each form; peak RSS has
to stay flat instead of growing by about 180 MB."""

import from tests.support { jac_command }
import os;
import re;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }

glob FIXTURE = str(
         Path(__file__).resolve().parent / "fixtures" / "fstring_piece_release.jac"
     ),
     _BIN: list[str] = [];

def _binary -> str {
    if _BIN {
        return _BIN[0];
    }
    out = os.path.join(tempfile.mkdtemp(), "fstring_piece_release");
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

test "an f-string releases a slice made for one of its pieces" {
    (rss, out) = _run("slice");
    assert out == "52888890" , out;
    assert 0 <= rss < 40 , f"peak RSS {rss} MB";
}

test "an f-string releases a string a call made for one of its pieces" {
    (rss, out) = _run("upper");
    assert out == "39000000" , out;
    assert 0 <= rss < 40 , f"peak RSS {rss} MB";
}

test "optional, !r and formatted string pieces are released once" {
    fixture = str(
        Path(__file__).resolve().parent / "fixtures" / "fstring_piece_release_leaks.jac"
    );
    for memory in ["rc", "managed"] {
        with tempfile.TemporaryDirectory() as scratch {
            binary = os.path.join(scratch, "probe");
            comp = subprocess.run(
                jac_command(
                    "build",
                    "--native",
                    fixture,
                    "--memory",
                    memory,
                    "--debug",
                    "-o",
                    binary
                ),
                capture_output=True,
                text=True,
                timeout=900
            );
            assert comp.returncode == 0 , comp.stderr[-1500:];
            proc = subprocess.run(
                [binary], capture_output=True, text=True, timeout=120
            );
            assert proc.returncode == 0 , proc.stderr[-800:];
        }
        out = proc.stdout + proc.stderr;
        assert "DOUBLE-FREE" not in out , f"{memory}: a piece was released twice: {out[:600]}";
        lines = [
            line
            for line in proc.stdout.splitlines()
            if not line.startswith("RC ")
        ];
        assert lines[0]
            == "120 ello world [ello world] <'ello world'> | HELLO WORLD|" , (
            f"{memory}: {proc.stdout[:400]}"
        );
        assert "RC LIVE OBJECTS at exit" in proc.stdout , proc.stdout[-400:];
        leaks = [
            line
            for line in proc.stdout.splitlines()
            if "<- LEAK" in line
        ];
        assert not leaks , f"{memory}: {leaks[:5]}";
    }
}
