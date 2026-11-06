"""A JIT engine rebuilt from cached unit objects binds the root's Python bridges.

A native unit that calls back into a Python function of its own module
reaches it through a `__jac_na_import_*` bridge symbol. A fresh compile
registers the root module's bridges before it builds the engine. The engine
for a module loaded from the cache used to be built first and its bridges
registered after, so the objects-mode link finalized with the bridge
unresolved, and the next address lookup wrote the late relocation into
already-executable memory: the second process to run the program died on
SIGSEGV. Each run here is its own process, so the second one takes the
cached path.
"""
import os;
import subprocess;
import tempfile;
import jaclang;
import from pathlib { Path }
import from tests.support { compiler_python_command }

glob _PREPARE_DRIVER = """
import os
import sys
import jaclang

assert os.path.realpath(jaclang.__file__) == os.path.realpath(sys.argv[2]), (
    "the subprocess selected a different compiler package", jaclang.__file__, sys.argv[2]
)

from jaclang.compiler.driver.application import prepare_application
from jaclang.compiler.driver.program import JacProgram
from jaclang.runtime.prepared import initialize_application

root = sys.argv[1]
prepared = prepare_application(os.path.join(root, 'main.jac'), JacProgram(), root)
if prepared.native.get(os.path.join(root, 'main.jac'), (None, None))[0] is None:
    raise SystemExit('no native engine for main.jac')
print(initialize_application(prepared).answer())
""";


"""Run the prepared application at `project` once, in its own process."""
def _run_once(project: str) -> tuple[(int, str, str)] {
    proc = subprocess.run(
        compiler_python_command(_PREPARE_DRIVER, project, str(jaclang.__file__)),
        capture_output=True,
        text=True,
        timeout=900
    );
    return (proc.returncode, proc.stdout.strip(), proc.stderr);
}


test "a program whose native unit calls Python runs again from the cache" {
    with tempfile.TemporaryDirectory(prefix='jac-jit-cached-bridges-') as tmp {
        base = Path(tmp);
        (base / 'jac.toml').write_text('[placement.pins]\n"main.positive"="native"\n');
        (base / 'main.jac').write_text(
            'def positive(value: int) -> int { return -value; }\n'
                + 'def:pub answer -> int { return positive(-5); }\n'
        );
        for run in ["first", "second"] {
            (code, out, err) = _run_once(tmp);
            assert code >= 0 , (
                f"the {run} run died on signal {-code}: the engine was "
                f"finalized before the root's Python bridges were bound\n{err[-800:]}"
            );
            assert code == 0 , f"the {run} run failed: {err[-800:]}";
            assert out.splitlines()[-1:] == ["5"] , f"the {run} run printed {out!r}";
        }
    }
}
