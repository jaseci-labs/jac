import subprocess;
import sys;
import tempfile;
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


test "full compiler output initializes the runtime foundation without a seed" {
    package = Path(str(jaclang.__file__)).parent;
    sources = [
        "runtime/exports",
        "runtime/access_level",
        "runtime/object_model",
        "runtime/function_metadata",
        "runtime/builtin",
        "runtime/region",
        "runtime/scalars",
        "runtime/archetype",
        "lib/jaclib",
        "lib/__init__",
        "compiler/frontend/constant"
    ];
    with tempfile.TemporaryDirectory() as directory {
        destination = Path(directory) / "jaclang";
        destination.mkdir();
        (destination / "__init__.py").write_text("");
        for relative in sources {
            program = JacProgram();
            try {
                module = program.compile(
                    file_path=str(package / (relative + ".jac")),
                    options=CompileOptions(
                        force_target_program=True,
                        force_codespace="server",
                        need_full_ast=True,
                        no_ir_cache=True
                    )
                );
                assert module is not None and module.gen.py_bytecode;
                output = destination / (relative + ".py");
                output.parent.mkdir(parents=True, exist_ok=True);
                parent = output.parent;
                while parent != destination {
                    if not (parent / "__init__.py").exists() {
                        (parent / "__init__.py").write_text("");
                    }
                    parent = parent.parent;
                }
                output.write_text(str(module.gen.py));
            } finally {
                program.release_compile_closure();
            }
        }
        probe = (
            "from __future__ import annotations\n"
            "import sys\n"
            "sys.path.insert(0, sys.argv[1])\n"
            "from jaclang.runtime.archetype import Access, Permission, AccessLevel, Archetype, Anchor\n"
            "assert Access().anchors == {}\n"
            "assert Permission().all == AccessLevel.NO_ACCESS\n"
            "class Record(Archetype):\n"
            "    value: int = 42\n"
            "assert Record().value == 42\n"
            "assert Record(value=7).value == 7\n"
            "anchor = Anchor(archetype=Record())\n"
            "assert anchor.persistent is False\n"
            "anchor.persistent = True\n"
            "assert anchor.persistent is True\n"
            "from jaclang.runtime.exports import runtime_function\n"
            "operation = runtime_function('example')\n"
            "assert operation is runtime_function('example')\n"
            "assert 'jaclang.runtime.runtime' not in sys.modules\n"
            "import types\n"
            "owner = types.ModuleType('jaclang.runtime.runtime')\n"
            "owner.JacRuntimeInterface = types.SimpleNamespace(example=lambda value: value + 1)\n"
            "sys.modules[owner.__name__] = owner\n"
            "assert operation(41) == 42\n"
            "assert not any(n.startswith('jaclang.jac0') for n in sys.modules)\n"
        );
        result = subprocess.run(
            [sys.executable, "-I", "-S", "-c", probe, directory],
            capture_output=True,
            text=True
        );
        assert result.returncode == 0 , result.stderr;
    }
}
