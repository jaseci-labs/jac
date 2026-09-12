import subprocess;
import sys;
import from pathlib { Path }
import jaclang;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.runtime.function_metadata { impl_patch_filename }

test "compiled runtime facade loads without initializing the runtime" {
    source = Path(str(jaclang.__file__)).parent / "lib" / "jaclib.jac";
    program = JacProgram();
    module = program.compile(
        file_path=str(source),
        options=CompileOptions(force_target_program=True, force_codespace="server")
    );
    assert module is not None and module.gen.py_bytecode;
    code = module.gen.py_bytecode;
    program.release_compile_closure();
    probe = (
        "import marshal, sys\n"
        "namespace = {'__name__': 'runtime_exports'}\n"
        "exec(marshal.loads(sys.stdin.buffer.read()), namespace)\n"
        "assert not any(n == 'jaclang' or n.startswith('jaclang.') for n in sys.modules)\n"
        "try:\n"
        "    namespace['__getattr__']('does_not_exist')\n"
        "except AttributeError:\n"
        "    pass\n"
        "else:\n"
        "    raise AssertionError('unknown export was accepted')\n"
    );
    result = subprocess.run(
        [sys.executable, "-I", "-S", "-c", probe], input=code, capture_output=True
    );
    assert result.returncode == 0 , result.stderr.decode();
}

test "implementation filename updates preserve callable behavior and metadata" {
    def add(value: int, extra: int = 7) -> int {
        return value + extra;
    }
    prior = add.__code__;
    patched = impl_patch_filename("implementation.impl.jac")(add);
    assert patched is add;
    assert patched(35) == 42;
    assert patched.__code__.co_filename == "implementation.impl.jac";
    assert patched.__code__.co_code == prior.co_code;
    assert patched.__code__.co_firstlineno == prior.co_firstlineno;
    assert patched.__defaults__ == (7, );
    assert impl_patch_filename("ignored")(len) is len;
}
