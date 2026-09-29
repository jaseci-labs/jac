"""C buffer arguments keep their payload pointer across aggregate ABI lowering."""
import ctypes;
import os;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support { get_func, jac_command, native_force_opts }
import from jaclang.compiler.driver.program { JacProgram }

def prepare_probe(directory: str) -> str {
    cc = shutil.which("cc") or shutil.which("gcc");
    if not cc {
        testskip("no C compiler available for the reference library");
    }
    source = Path(__file__).parent / "fixtures" / "clib_aggregate_bytes.c";
    library = str(Path(directory) / "libaggregate_bytes.so");
    built = subprocess.run(
        [cc, "-shared", "-fPIC", str(source), "-o", library],
        capture_output=True,
        text=True,
        timeout=60
    );
    assert built.returncode == 0 , built.stderr;
    code = '''import from "LIBRARY" {
    obj Small {has first: i64, last: i64;}
    obj Large {has first: i64, last: i64, length: i64;}
    def small_bytes(data: bytes, n: i32) -> Small;
    def large_bytes(data: bytes, n: i32) -> Large;
    def mixed_bytes(prefix: Small, a: bytes, label: str, b: bytes, n: i32) -> i64;
}

def register_return() -> bool {
    data = b"\\x7f\\x00\\xff";
    result = small_bytes(data, i32(len(data)));
    return int(result.first) == 127 and int(result.last) == 255;
}
def indirect_return() -> bool {
    data = b"\\x7f\\x00\\xff";
    result = large_bytes(data, i32(len(data)));
    return int(result.first) == 127 and int(result.last) == 255 and int(result.length) == 3;
}
def empty_buffers() -> bool {
    small = small_bytes(b"", i32(0));
    large = large_bytes(b"", i32(0));
    return int(small.first) == 0 and int(small.last) == 0
        and int(large.first) == 0 and int(large.last) == 0 and int(large.length) == 0;
}
def temporary_buffers() -> bool {
    data = b"ignore\\x7f\\x00\\xff";
    result = large_bytes(data[6:], i32(3));
    small = small_bytes(b"\\x7f" + b"\\x00\\xff", i32(3));
    return int(result.first) == 127 and int(result.last) == 255 and int(result.length) == 3
        and int(small.first) == 127 and int(small.last) == 255;
}
def struct_argument() -> bool {
    prefix = Small(first=i64(5), last=i64(7));
    return int(mixed_bytes(prefix, b"\\x7f\\x00", "A", b"\\x00\\xff", i32(2))) == 13032;
}
with entry {
    assert register_return() and indirect_return() and empty_buffers();
    assert temporary_buffers() and struct_argument();
    print("aggregate bytes OK");
}
'''.replace(
        "LIBRARY", library
    );
    path = str(Path(directory) / "probe.jac");
    Path(path).write_text(code);
    return path;
}

test "aggregate C calls pass bytes payloads for register and indirect returns" {
    with tempfile.TemporaryDirectory() as directory {
        path = prepare_probe(directory);
        program = JacProgram();
        result = program.compile(file_path=path, options=native_force_opts());
        assert not program.errors_had , str(program.errors_had);
        engine = result.gen.native_engine;
        assert engine is not None;
        for name in [
            "register_return",
            "indirect_return",
            "empty_buffers",
            "temporary_buffers",
            "struct_argument"
        ] {
            probe = get_func(engine, name, ctypes.c_bool);
            for _ in range(25) {
                assert probe() , name;
            }
        }
    }
}

test "aggregate bytes signatures work in a standalone native executable" {
    with tempfile.TemporaryDirectory() as directory {
        path = prepare_probe(directory);
        binary = str(Path(directory) / "probe");
        built = subprocess.run(
            jac_command("build", path, "--native", "-o", binary),
            capture_output=True,
            text=True,
            timeout=180
        );
        assert built.returncode == 0 , built.stdout + built.stderr;
        ran = subprocess.run([binary], capture_output=True, text=True, timeout=30);
        assert ran.returncode == 0 , ran.stdout + ran.stderr;
        assert "aggregate bytes OK" in ran.stdout;
    }
}
