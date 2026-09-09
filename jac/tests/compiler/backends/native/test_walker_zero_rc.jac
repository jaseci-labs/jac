"""Walker-engine zero-RC factoring (#7870 item 5): the enforced build
of a build-traverse-discard walker kernel over an owned region graph
passes the audit, links, runs, and reproduces the
managed digest exactly -- the inherited acceptance from #7857. The OSP
kernel compiles under the user module's memory mode (headerless when
enforced); graph archetypes and the engine's own structs (WalkScope,
NodeDesc, ...) are engine-owned and exempt from scope drops; globals
transfer ownership on store and mark aliases no-free; and container
drops fire only on ownership ops, so the engine's compensating
releases (balanced by retains only under managed modes) never
double-free."""

import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "own_walk_kernel.jac"
     );

test "enforced walker kernel runs rc-free with the managed digest" {
    with tempfile.TemporaryDirectory() as tmp {
        out_bin = os.path.join(tmp, "ownwalk_none");
        res = subprocess.run(
            [
                sys.executable,
                "-m",
                "jaclang",
                "build",
                "--native",
                FIXTURE,
                "--memory",
                "nogc",
                "-o",
                out_bin
            ],
            capture_output=True,
            text=True
        );
        assert res.returncode == 0 , f"audit failed: {res.stderr}";
        assert os.path.exists(out_bin) , "no binary written";
        rc_bin = os.path.join(tmp, "ownwalk_rc");
        rcc = subprocess.run(
            [
                sys.executable,
                "-m",
                "jaclang",
                "build",
                "--native",
                FIXTURE,
                "--memory",
                "rc",
                "-o",
                rc_bin
            ],
            capture_output=True,
            text=True
        );
        assert rcc.returncode == 0 , rcc.stderr;
        rc_out = subprocess.run([rc_bin], capture_output=True, text=True);
        assert rc_out.returncode == 0 , rc_out.stderr;
        cy_bin = os.path.join(tmp, "ownwalk_cy");
        cyc = subprocess.run(
            [
                sys.executable,
                "-m",
                "jaclang",
                "build",
                "--native",
                FIXTURE,
                "--memory",
                "managed",
                "-o",
                cy_bin
            ],
            capture_output=True,
            text=True
        );
        assert cyc.returncode == 0 , cyc.stderr;
        cy_out = subprocess.run([cy_bin], capture_output=True, text=True);
        assert cy_out.stdout == rc_out.stdout , (f"{cy_out.stdout} vs {rc_out.stdout}");
        none_out = subprocess.run([out_bin], capture_output=True, text=True);
        assert none_out.returncode == 0 , f"enforced run failed: {none_out.stderr}";
        assert none_out.stdout == rc_out.stdout , (
            f"enforced digest diverges: {none_out.stdout} vs {rc_out.stdout}"
        );
    }
}
