"""A construct too deep to compile reports where it is, and a program that
recurses at runtime keeps its own failure."""

import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { JAC_ROOT }

def run_source(dir: str, source: str) -> str {
    path = os.path.join(dir, "probe.jac");
    with open(path, "w") as f {
        f.write(source);
    }
    result = subprocess.run(
        [sys.executable, "-m", "jaclang", "run", "-b", "python", path],
        capture_output=True,
        text=True,
        cwd=JAC_ROOT
    );
    return result.stdout + result.stderr;
}

test "a chain too deep to compile reports the construct" {
    with tempfile.TemporaryDirectory() as dir {
        chain = "+".join(["1"] * 20000);
        out = run_source(dir, f"with entry {{\n    x = {chain};\n}}\n");
        assert "E0111" in out , out;
        assert "probe.jac:2:" in out , out;
        assert "maximum recursion depth" not in out , out;
    }
}

test "nesting too deep to compile reports the construct" {
    with tempfile.TemporaryDirectory() as dir {
        nested = "(" * 3000 + "1" + ")" * 3000;
        out = run_source(dir, f"with entry {{\n    x = {nested};\n}}\n");
        assert "E0111" in out , out;
        assert "probe.jac:2:" in out , out;
        assert "maximum recursion depth" not in out , out;
    }
}

test "nesting within the limit still compiles and runs" {
    with tempfile.TemporaryDirectory() as dir {
        nested = "(" * 150 + "7" + ")" * 150;
        out = run_source(dir, f"with entry {{\n    print({nested});\n}}\n");
        assert "E0111" not in out , out;
        assert "7" in out.splitlines() , out;
    }
}

test "recursion while running the program keeps its own failure" {
    with tempfile.TemporaryDirectory() as dir {
        out = run_source(
            dir,
            "def recurse -> int {\n    return recurse();\n}\n"
            "with entry {\n    recurse();\n}\n"
        );
        assert "maximum recursion depth" in out , out;
        assert "recurse" in out , out;
        assert "E0111" not in out , out;
    }
}
