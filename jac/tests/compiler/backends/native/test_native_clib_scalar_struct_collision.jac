"""Foreign integer returns must not become unrelated same-width C structs."""
import ctypes;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support { get_func, jac_command, native_force_opts }
import from jaclang.compiler.driver.program { JacProgram }

def prepare_collision(directory: str) -> str {
    cc = shutil.which("cc") or shutil.which("gcc");
    if not cc {
        testskip("C compiler required");
    }
    folder = Path(directory);
    library = str(folder / "libcollision.so");
    source = Path(__file__).parent / "fixtures" / "clib_scalar_struct_collision.c";
    built = subprocess.run(
        [cc, "-shared", "-fPIC", str(source), "-o", library],
        capture_output=True,
        text=True,
        timeout=60
    );
    assert built.returncode == 0 , built.stderr;
    (folder / "shapes.jac").write_text(
        '''import from "LIBRARY" {
    obj ByteBox { has value: u8; }
    obj ShortBox { has value: u16; }
    obj Color { has r: u8, g: u8, b: u8, a: u8; }
    obj WordBox { has value: u32; }
    obj LongBox { has value: u64; }
    def color_value -> Color;
    def word_value -> WordBox;
    def long_value -> LongBox;
}
'''.replace(
            "LIBRARY", library
        )
    );
    (folder / "scalars.jac").write_text(
        '''import from "LIBRARY" {
    def scalar8 -> i8;
    def scalar16 -> i16;
    def scalar32 -> i32;
    def scalar64 -> i64;
    def unsigned32 -> u32;
}
'''.replace(
            "LIBRARY", library
        )
    );
    code = '''import from shapes { ByteBox, ShortBox, Color, WordBox, LongBox, color_value, word_value, long_value }
import from scalars { scalar8, scalar16, scalar32, scalar64, unsigned32 }
obj Probe {
    def integer() -> int { return int(scalar32()); }
}
def scalar_values() -> bool {
    return int(scalar8()) == -7 and int(scalar16()) == -1234
        and Probe().integer() == -123456 and int(scalar64()) == -12345678901
        and int(unsigned32()) == 4294967295;
}
def struct_values() -> bool {
    c = color_value(); w = word_value(); l = long_value();
    return int(c.r) == 11 and int(c.g) == 22 and int(c.b) == 33 and int(c.a) == 44
        and int(w.value) == 987654 and int(l.value) == 12345678901;
}
with entry {
    assert scalar_values(); assert struct_values();
    print("scalar and struct returns OK");
}
''';
    path = str(folder / "probe.jac");
    Path(path).write_text(code);
    return path;
}

test "foreign scalars preserve declared types beside equal width structs" {
    with tempfile.TemporaryDirectory() as directory {
        path = prepare_collision(directory);
        program = JacProgram();
        result = program.compile(file_path=path, options=native_force_opts());
        assert not program.errors_had , str(program.errors_had);
        engine = result.gen.native_engine;
        assert engine is not None;
        for name in ["scalar_values", "struct_values"] {
            probe = get_func(engine, name, ctypes.c_bool);
            for _ in range(25) {
                assert probe() , name;
            }
        }
    }
}

test "standalone C calls distinguish scalar and same width aggregate results" {
    with tempfile.TemporaryDirectory() as directory {
        path = prepare_collision(directory);
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
        assert "scalar and struct returns OK" in ran.stdout;
    }
}
