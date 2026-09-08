"""Inherited user destructors run once under every native memory profile."""
import os;
import subprocess;
import tempfile;
import from tests.support { native_build, NATIVE_FIXTURES, NATIVE_MEMORY_PROFILES }

test "inherited drop follows the nearest override in every memory profile" {
    with tempfile.TemporaryDirectory() as directory {
        for memory in NATIVE_MEMORY_PROFILES {
            binary = os.path.join(directory, memory);
            native_build(
                os.path.join(NATIVE_FIXTURES, "inherited_drop.jac"),
                binary,
                memory=memory
            );
            result = subprocess.run(
                [binary], capture_output=True, text=True, timeout=30
            );
            assert result.returncode == 0 , memory + ": " + result.stderr;
            assert result.stdout.splitlines() == ["12", "5", "7"] , (
                memory + ": " + result.stdout
            );
        }
    }
}
