import os;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.driver.image { _jaclang_image }

test "compiled compiler initializes and runs in an isolated interpreter" {
    image = _jaclang_image();
    if image is None or not image.manifest.get("producer_digest") {
        testskip("requires a staged compiler image (zig build compiler-image)");
    }
    assert image is not None;
    site = image.pkg_dir.parent;
    probe = '''import marshal
import sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
import jaclang
from jaclang.compiler.driver.image import _jaclang_image
image = _jaclang_image()
assert image is not None
image.verify()
package = Path(jaclang.__file__).resolve().parent
assert not (package / "jac0.py").exists()
assert not (package / "jac0core").exists()
assert not (package / "bootstrap_manifest.py").exists()
from jaclang.compiler.driver.program import JacProgram
from jaclang.compiler.driver.compile_options import CompileOptions
program = JacProgram()
module = program.compile(
    file_path="<image-smoke>",
    use_str="with entry { print(6 * 7); }",
    options=CompileOptions(force_codespace="server", no_ir_cache=True),
)
assert module is not None and module.gen.py_bytecode, program.errors_had
exec(marshal.loads(module.gen.py_bytecode), {"__name__": "__main__"})
assert not any(name == "jaclang.jac0" or name.startswith("jaclang.jac0core") for name in sys.modules)
assert Path(JacProgram.__init__.__code__.co_filename).is_relative_to(package)
print("image verified")
''';
    env = dict(os.environ);
    for name in (
        "JAC_DEV_SOURCE",
        "JAC_COMPILER_IMAGE",
        "JAC_COMPILER_LIB",
        "JAC_LLVM_SHIM",
        "JACPATH"
    ) {
        env.pop(name, None);
    }
    env["JAC_NO_DEV_SOURCE"] = "1";
    with tempfile.TemporaryDirectory() as work {
        result = subprocess.run(
            [sys.executable, "-I", "-S", "-c", probe, str(site)],
            cwd=work,
            env=env,
            capture_output=True,
            text=True,
            timeout=180
        );
    }
    assert result.returncode == 0 , result.stdout + result.stderr;
    assert "42\nimage verified" in result.stdout;
}
