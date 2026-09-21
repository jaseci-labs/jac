import ctypes;
import os;
import shutil;
import subprocess;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.compiler.backends.native.c_emit { emit_c }

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

test "C allocation attributes use the allocator argument positions" {
    cc = c_compiler();
    source = """
declare ptr @malloc(i64) allocsize(0)
declare ptr @realloc(ptr, i64) allocsize(1)
declare ptr @calloc(i64, i64) allocsize(0, 1)
declare void @free(ptr)
define void @exercise(i64 %n) {
  %a = call ptr @malloc(i64 %n)
  %b = call ptr @realloc(ptr %a, i64 %n)
  %c = call ptr @calloc(i64 2, i64 %n)
  call void @free(ptr %b)
  call void @free(ptr %c)
  ret void
}
""";
    with TemporaryDirectory() as tmp {
        path = Path(tmp) / 'allocators.c';
        path.write_text(emit_c(source));
        library = Path(tmp) / 'allocators.so';
        built = subprocess.run(
            [
                cc,
                '-shared',
                '-fPIC',
                '-Werror=attributes',
                str(path),
                '-o',
                str(library)
            ],
            capture_output=True,
            text=True
        );
        assert built.returncode == 0 , built.stderr;
        exercise = ctypes.CDLL(str(library)).exercise;
        exercise.argtypes = [ctypes.c_uint64];
        exercise.restype = None;
        exercise(8);
    }
}

test "C exception handlers include the standard jump buffer definitions" {
    cc = c_compiler();
    source = '''
declare i32 @setjmp(ptr) returns_twice
declare void @longjmp(ptr, i32) noreturn
declare i32 @sigsetjmp(ptr, i32) returns_twice
declare void @siglongjmp(ptr, i32) noreturn
''';
    for (name, save, restore, extra) in [
        ('plain', 'setjmp', 'longjmp', ''),
        ('signal', 'sigsetjmp', 'siglongjmp', ', i32 0')
    ] {
        source += f'define i32 @exercise_{name}(i32 %code) {{\n'
            + '  %buffer = alloca [512 x i8], align 16\n'
            + f'  %result = call i32 @{save}(ptr %buffer{extra})\n'
            + '  %initial = icmp eq i32 %result, 0\n'
            + '  br i1 %initial, label %jump, label %done\n'
            + 'jump:\n'
            + f'  call void @{restore}(ptr %buffer, i32 %code)\n'
            + '  unreachable\n'
            + 'done:\n'
            + '  ret i32 %result\n'
            + '}\n';
    }
    with TemporaryDirectory() as tmp {
        path = Path(tmp) / 'exceptions.c';
        path.write_text(emit_c(source));
        library = Path(tmp) / 'exceptions.so';
        built = subprocess.run(
            [cc, '-O2', '-shared', '-fPIC', str(path), '-o', str(library)],
            capture_output=True,
            text=True
        );
        assert built.returncode == 0 , built.stderr;
        loaded = ctypes.CDLL(str(library));
        for name in ['plain', 'signal'] {
            exercise = getattr(loaded, f'exercise_{name}');
            exercise.argtypes = [ctypes.c_int32];
            exercise.restype = ctypes.c_int32;
            for code in [7, 0, -3] {
                assert exercise(code) == (code or 1);
            }
        }
    }
}

test "C projection preserves signed and unsigned three way comparisons" {
    cc = c_compiler();
    source = '';
    for kind in ['scmp', 'ucmp'] {
        source += f'declare i32 @llvm.{kind}.i32.i64(i64, i64)\n'
            + f'define i32 @{kind}(i64 %a, i64 %b) {{\n'
            + f'  %r = call i32 @llvm.{kind}.i32.i64(i64 %a, i64 %b)\n'
            + '  ret i32 %r\n}\n';
    }
    with TemporaryDirectory() as tmp {
        base = Path(tmp);
        path = base / 'compare.c';
        path.write_text(emit_c(source));
        library = base / 'compare.so';
        built = subprocess.run(
            [cc, '-shared', '-fPIC', str(path), '-o', str(library)],
            capture_output=True,
            text=True
        );
        assert built.returncode == 0 , built.stderr;
        loaded = ctypes.CDLL(str(library));
        for (name, arg_type, cases) in [
            (
                'scmp',
                ctypes.c_int64,
                [(-9223372036854775808, 9223372036854775807), (-1, 0), (0, 0), (1, -1)]
            ),
            (
                'ucmp',
                ctypes.c_uint64,
                [
                    (0, 18446744073709551615),
                    (0, 0),
                    (18446744073709551615, 1),
                    (9223372036854775808, 9223372036854775807)
                ]
            )
        ] {
            compare = getattr(loaded, name);
            compare.argtypes = [arg_type, arg_type];
            compare.restype = ctypes.c_int32;
            for (a, b) in cases {
                assert compare(a, b) == int(a > b) - int(a < b);
            }
        }
    }
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
