"""A chain too long to compile reports where it is, not a raw crash.

The chain is generated rather than committed: at these sizes the fixture
would be tens of kilobytes of source.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { JAC_ROOT }

def write_chain(dir: str, operands: int) -> str {
    path = os.path.join(dir, "chain.jac");
    body = "+".join(["1"] * operands);
    with open(path, "w") as f {
        f.write(f"with entry {{\n    x = {body};\n    print(x);\n}}\n");
    }
    return path;
}

def run_jac(cmd: str, path: str) -> str {
    result = subprocess.run(
        [sys.executable, "-m", "jaclang", cmd, path],
        capture_output=True,
        text=True,
        cwd=JAC_ROOT
    );
    return result.stdout + result.stderr;
}

test "a chain past the limit explains itself instead of crashing" {
    with tempfile.TemporaryDirectory() as dir {
        out = run_jac("run", write_chain(dir, 20000));
        assert "maximum recursion depth" not in out , out;
        assert "deeply" in out , out;
        assert "Split it across several statements" in out , out;
    }
}
