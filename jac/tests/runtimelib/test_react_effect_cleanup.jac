"""Execute compiled lifecycle cleanup through dependency changes and StrictMode."""
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.compiler.backends.es.backends.react { ReactBackend }
import from jaclang.client.bun_installer { get_bun }
import from .react_jsdom_harness {
    bun_install,
    compile_page,
    require_client_integration,
    run_harness,
    write_runtime
}

glob HARNESS: str = """
import { JSDOM } from 'jsdom';
const dom = new JSDOM('<div id="root"></div>', {url: 'http://localhost/'});
globalThis.window = dom.window;
for (const key of ['document', 'navigator', 'HTMLElement', 'Node', 'localStorage']) {
    Object.defineProperty(globalThis, key, {value: dom.window[key], configurable: true});
}
globalThis.IS_REACT_ACT_ENVIRONMENT = true;
const React = await import('react');
const {createRoot} = await import('react-dom/client');
const {app, history} = await import('./component.js');
const assert = (ok, message) => {if (!ok) throw Error(message + ': ' + JSON.stringify(history()));};
const root = createRoot(document.getElementById('root'));
await React.act(async () => root.render(React.createElement(React.StrictMode, null, React.createElement(app))));
const steps = () => history().filter(x => x !== 'exit');
assert(JSON.stringify(steps()) === JSON.stringify(['setup:0', 'cleanup:0', 'setup:0']), 'StrictMode setup and cleanup');
const ping = () => window.dispatchEvent(new window.Event('jac-ping'));
ping();
assert(steps().filter(x => x === 'event:0').length === 1, 'only one listener survives StrictMode');
const before = history().length;
await React.act(async () => document.getElementById('unrelated').click());
assert(history().length === before, 'unrelated renders preserve subscription');
await React.act(async () => document.getElementById('next').click());
assert(JSON.stringify(steps().slice(-2)) === JSON.stringify(['cleanup:0','setup:1']), 'cleanup precedes changed dependency setup');
ping();
assert(steps().at(-1) === 'event:1' && steps().filter(x => x === 'event:0').length === 1, 'old listener removed');
await React.act(async () => document.getElementById('next').click());
assert(steps().at(-1) === 'cleanup:1', 'early return still releases previous resource');
const idle = history().length;
ping();
assert(history().length === idle, 'early return has no listener');
await React.act(async () => document.getElementById('next').click());
assert(steps().at(-1) === 'setup:3', 'setup resumes after early return');
await React.act(async () => root.unmount());
assert(steps().at(-1) === 'cleanup:3', 'unmount cleanup captures latest setup handle');
assert(history().filter(x => x === 'exit').length === 2, 'standalone exit runs for StrictMode and unmount');
const ended = history().length;
ping();
assert(history().length === ended, 'unmount removes listener');
console.log('PASS lifecycle cleanup: StrictMode, dependencies, early return, unmount');
dom.window.close();
""";

test "returned lifecycle cleanup releases the correct resource" {
    require_client_integration("React lifecycle cleanup");
    bun = get_bun();
    if bun is None {
        testskip("bun is required");
    }
    fixture = Path(__file__).parent.parent
        / "compiler"
        / "backends"
        / "es"
        / "fixtures"
        / "reactive_effects_return_cleanup.jac";
    component = compile_page(str(fixture), ReactBackend());
    with TemporaryDirectory() as tmp {
        work = Path(tmp);
        (work / "component.js").write_text(component, encoding="utf-8");
        write_runtime(work);
        (work / "harness.mjs").write_text(HARNESS, encoding="utf-8");
        bun_install(bun, work, "jac-effect-cleanup-test");
        run_harness(bun, work, [], "React lifecycle cleanup");
    }
}
