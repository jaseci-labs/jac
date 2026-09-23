"""Construction through class values must lower natively and match the Python tier.

A `type[B]` value is called with arguments bound against `B`'s constructor
signature. The class held at runtime may be `B` or any subclass, including one
declared in another module; each class registers construct entries keyed by the
ancestors whose signatures it accepts. A subclass that cannot accept the bound's
arguments raises `TypeError`, as the Python tier does.
"""

import os;
import subprocess;
import tempfile;
import from tests.support {
    jac_command,
    native_memory_flags,
    NATIVE_MEMORY_PROFILES,
    TESTS_DIR
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     EXPECTED: list[str] = [
         "9 3",
         "16",
         "2 True",
         "-1 25",
         "1 100 7",
         "5 2 9",
         "-1 11 7",
         "12",
         "36",
         "49",
         "5 3",
         "10 25 -1",
         "4 2",
         "9 1 4"
     ];

def output_lines(text: str) -> list[str] {
    return [
        line
        for line in text.split("\n")
        if line.strip()
    ];
}

def python_tier_run(fixture: str) -> list[str] {
    proc = subprocess.run(
        jac_command("run", "-b", "python", os.path.join(FIXTURES, fixture)),
        capture_output=True,
        text=True,
        timeout=900
    );
    assert proc.returncode == 0 , f"python tier failed: {proc.stderr[-800:]}";
    return output_lines(proc.stdout);
}

def native_run(fixture: str, memory: str = "rc") -> list[str] {
    binary = os.path.join(tempfile.mkdtemp(), "class_values.bin");
    build = subprocess.run(
        jac_command(
            "build",
            "--native",
            *native_memory_flags(memory),
            os.path.join(FIXTURES, fixture),
            "-o",
            binary
        ),
        capture_output=True,
        text=True,
        timeout=900
    );
    assert build.returncode == 0 , f"native build failed: {build.stderr[-1200:]}";
    proc = subprocess.run([binary], capture_output=True, text=True, timeout=120);
    assert proc.returncode == 0 , f"binary exited {proc.returncode}: {proc.stderr[-400:]}";
    return output_lines(proc.stdout);
}

test "class values construct natively as the Python tier does" {
    native = native_run("class_value_ctors.jac");
    assert native == EXPECTED , f"native output {native}";
    assert python_tier_run("class_value_ctors.jac") == native;
}

test "class-value construction holds under every memory profile" {
    for memory in NATIVE_MEMORY_PROFILES {
        assert native_run("class_value_ctors_memory.jac", memory) == ["15"] , memory;
    }
}
