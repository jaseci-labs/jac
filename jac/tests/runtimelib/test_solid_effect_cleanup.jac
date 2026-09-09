"""Execute the Solid backend's returned cleanup against real reactive owners."""
import subprocess;
import shutil;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.client.bun_installer { get_bun }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.pass_driver { run_pass }
import from jaclang.compiler.backends.es { EsastGenPass }
import from jaclang.compiler.backends.es.backends.solid { SolidBackend }
import from jaclang.compiler.backends.es.es_unparse { es_to_js }
import from .react_jsdom_harness { bun_install, require_client_integration }

glob HARNESS: str = """
import {createRoot, createSignal} from 'solid-js';
import {subscribe} from './component.js';
const events = [];
const [value, setValue] = createSignal(0);
const dispose = createRoot(dispose => { subscribe(value, events); return dispose; });
const check = expected => {
    if (JSON.stringify(events) !== JSON.stringify(expected)) throw Error(JSON.stringify(events));
};
check(['setup:0']);
setValue(1);
check(['setup:0', 'cleanup:0', 'setup:1']);
setValue(2);
check(['setup:0', 'cleanup:0', 'setup:1', 'cleanup:1']);
setValue(3);
dispose();
check(['setup:0', 'cleanup:0', 'setup:1', 'cleanup:1', 'setup:3', 'cleanup:3']);
setValue(4);
check(['setup:0', 'cleanup:0', 'setup:1', 'cleanup:1', 'setup:3', 'cleanup:3']);
console.log('PASS Solid closure-local cleanup');
""";

test "solid returned cleanup runs on invalidation and disposal" {
    require_client_integration("Solid lifecycle cleanup");
    bun = get_bun();
    if bun is None {
        testskip("bun is required");
    }
    fixture = Path(__file__).parent.parent
        / "compiler"
        / "backends"
        / "es"
        / "fixtures"
        / "reactive_effects_solid_cleanup.jac";
    prog = JacProgram();
    ir = prog.compile(file_path=str(fixture), no_cgen=True);
    assert not prog.errors_had , str(prog.errors_had);
    result = run_pass(EsastGenPass, ir, prog, backend=SolidBackend());
    with TemporaryDirectory() as tmp {
        work = Path(tmp);
        (work / "component.js").write_text(
            es_to_js(result.ir_out.gen.es_ast), encoding="utf-8"
        );
        (work / "harness.mjs").write_text(HARNESS, encoding="utf-8");
        bun_install(bun, work, "solid-effect-cleanup-test", {"solid-js": "^1.9.13"});
        runner = shutil.which("node") or bun;
        result = subprocess.run(
            [runner, "--conditions=browser", str(work / "harness.mjs")],
            cwd=str(work),
            capture_output=True,
            text=True,
            timeout=60
        );
        assert result.returncode == 0 , result.stdout + result.stderr;
    }
}
