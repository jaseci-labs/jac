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
import tempfile;
import from tests.support { jac_command, TESTS_DIR }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "own_walk_kernel.jac"
     );

test "uncached walker builds preserve the kernel string ABI" {
    import from jaclang.cli.commands.native_build { native_build }
    import from jaclang.compiler.backends.native.na_ir_gen_pass { NaIRGenPass }
    import from unittest.mock { patch }
    load_kernel: any = NaIRGenPass._load_native_unit_module;

    def without_cached_layout(lowering: any, path: str) -> any {
        unit = load_kernel(lowering, path);
        if unit is not None {
            unit.gen.native_iface = None;
            unit.gen.native_layout = None;
            for key in [path, os.path.abspath(path), os.path.realpath(path)] {
                artifact = lowering.prog.hub.artifacts.get(key);
                if artifact is not None {
                    artifact.native_iface = None;
                    artifact.native_layout = None;
                }
            }
        }
        return unit;
    }

    with tempfile.TemporaryDirectory() as tmp {
        output = os.path.join(tmp, 'uncached_walker');
        with patch.object(
            NaIRGenPass, '_load_native_unit_module', without_cached_layout
        ) {
            assert native_build(FIXTURE, output=output, memory='nogc', no_ir_cache=True)
                == 0;
        }
        result = subprocess.run([output], capture_output=True, text=True);
        assert result.returncode == 0 , f"walker exited {result.returncode}: {result.stderr}";
        assert result.stdout.strip() == '814034290';
    }
}

test "enforced walker kernel runs rc-free with the managed digest" {
    with tempfile.TemporaryDirectory() as tmp {
        out_bin = os.path.join(tmp, "ownwalk_none");
        res = subprocess.run(
            jac_command(
                "build", "--native", FIXTURE, "--memory", "nogc", "-o", out_bin
            ),
            capture_output=True,
            text=True
        );
        assert res.returncode == 0 , f"audit failed: {res.stderr}";
        assert os.path.exists(out_bin) , "no binary written";
        rc_bin = os.path.join(tmp, "ownwalk_rc");
        rcc = subprocess.run(
            jac_command("build", "--native", FIXTURE, "--memory", "rc", "-o", rc_bin),
            capture_output=True,
            text=True
        );
        assert rcc.returncode == 0 , rcc.stderr;
        rc_out = subprocess.run([rc_bin], capture_output=True, text=True);
        assert rc_out.returncode == 0 , rc_out.stderr;
        cy_bin = os.path.join(tmp, "ownwalk_cy");
        cyc = subprocess.run(
            jac_command(
                "build", "--native", FIXTURE, "--memory", "managed", "-o", cy_bin
            ),
            capture_output=True,
            text=True
        );
        assert cyc.returncode == 0 , cyc.stderr;
        cy_out = subprocess.run([cy_bin], capture_output=True, text=True);
        assert cy_out.stdout == rc_out.stdout , (f"{cy_out.stdout} vs {rc_out.stdout}");
        none_out = subprocess.run([out_bin], capture_output=True, text=True);
        assert none_out.returncode == 0 , (
            f"enforced run failed ({none_out.returncode}): {none_out.stderr}"
            + f"\nstdout: {none_out.stdout}"
        );
        assert none_out.stdout == rc_out.stdout , (
            f"enforced digest diverges: {none_out.stdout} vs {rc_out.stdout}"
        );
    }
}
