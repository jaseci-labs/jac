import os;
import shutil;
import subprocess;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

def c_compiler -> str {
    if not os.environ.get('JAC_LLVM_CBE')
        and not (shutil.which('llvm-config-22') and shutil.which('cmake')) {
        testskip('LLVM C backend development toolchain is not installed');
    }
    cc = shutil.which('cc');
    if not cc {
        testskip('C compiler is not installed');
    }
    assert cc is not None;
    return cc;
}

test "native source executables use the C runtime startup and receive arguments" {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.dist.native_product { write_native_product }
    cc = c_compiler();
    with TemporaryDirectory() as tmp {
        base = Path(tmp);
        source = base / 'entry.jac';
        source.write_text(
            'import sys;\nwith entry { print(len(sys.argv)); print(sys.argv[1]); }\n'
        );
        program = JacProgram();
        module = program.compile(
            str(source),
            options=CompileOptions(aot_mode=True, default_codespace='native')
        );
        assert not program.errors_had;
        record = write_native_product(
            module, base, Path('main'), shared=False, program=program
        );
        binary = base / record['output'];
        built = subprocess.run(
            [
                cc,
                '-O2',
                '-fwrapv',
                '-fno-strict-aliasing',
                '-fno-builtin',
                str(base / record['source']),
                '-o',
                str(binary),
                '-lm'
            ],
            capture_output=True,
            text=True
        );
        assert built.returncode == 0 , built.stderr;
        result = subprocess.run([str(binary), 'hello'], capture_output=True, text=True);
        assert result.returncode == 0 , result.stderr;
        assert result.stdout == '2\nhello\n';
    }
}
