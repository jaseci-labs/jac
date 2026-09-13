import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.compilation_context {
    cache_scope,
    codegen_source_path
}
import from jaclang.compiler.backends.native.na_compile_pass { native_linked_ir_text }
import from jaclang.compiler.backends.native.shared_emit {
    init_object_codegen,
    inject_shared_init
}
import jaclang.compiler.backends.native.llvm.binding as llvm;

def emit_object(directory: Path, mapped: bool, debug: bool = False) -> bytes {
    directory.mkdir();
    (directory / 'jac.toml').write_text('[project]\nname="reproducible"\n');
    (directory / 'helper.jac').write_text(
        'glob count: int = 1;\ndef:pub echo(n: int) -> int { assert n >= 0; return n + count; }\n'
    );
    source = directory / 'main.jac';
    source.write_text(
        'import from helper { echo }\ndef:pub value -> int { return echo(1); }\n'
    );
    options = CompileOptions(
        aot_mode=True,
        default_codespace='native',
        no_ir_cache=True,
        native_target=llvm.get_default_triple(),
        native_debug=debug
    );
    if mapped {
        options.source_prefix_map = {str(directory): 'source'};
    }
    program = JacProgram();
    try {
        module = program.compile(str(source), options=options);
        assert not program.errors_had , '\n'.join(
            error.pretty_print() for error in program.errors_had
        );
        text = native_linked_ir_text(module);
        (text, _) = inject_shared_init(text, module.gen.interop_manifest);
        init_object_codegen();
        compiled = llvm.parse_assembly(text);
        compiled.verify();
        assert options.native_target is not None;
        machine = llvm.Target.from_triple(options.native_target).create_target_machine(
            opt=2, reloc='pic', codemodel='small'
        );
        return machine.emit_object(compiled);
    } finally {
        program.release_compile_closure();
    }
}

test "native objects are reproducible across mapped source directories" {
    with TemporaryDirectory() as td {
        base = Path(td).resolve();
        first = emit_object(base / 'first', True);
        second = emit_object(base / 'second', True);
        assert first == second;
        assert b'assertion failed at source/helper.jac' in first;
        assert str(base).encode() not in first;
        unmapped = emit_object(base / 'unmapped', False);
        assert first != unmapped;
        assert str(base / 'unmapped' / 'helper.jac').encode() in unmapped;
    }
}

test "source mappings use path boundaries and remain scoped to code generation" {
    with TemporaryDirectory() as td {
        base = Path(td).resolve();
        child = base / 'nested';
        options = CompileOptions(
            source_prefix_map={str(base): 'source', str(child): 'vendor'}
        );
        assert options.codegen_fingerprint() != CompileOptions().codegen_fingerprint();
        cloned = options.clone_for_native_import();
        assert cloned.source_prefix_map == options.source_prefix_map;
        assert cloned.source_prefix_map is not options.source_prefix_map;
        with cache_scope('mapped', options) {
            assert codegen_source_path(str(child / 'helper.jac'))
                == 'vendor/helper.jac';
            assert codegen_source_path(str(base / 'main.jac')) == 'source/main.jac';
            sibling = str(base) + '-sibling/main.jac';
            assert codegen_source_path(sibling) == sibling;
            with cache_scope('unmapped', CompileOptions()) {
                assert codegen_source_path(str(child / 'helper.jac'))
                    == str(child / 'helper.jac');
            }
            assert codegen_source_path(str(child / 'helper.jac'))
                == 'vendor/helper.jac';
        }
        assert codegen_source_path(str(child / 'helper.jac'))
            == str(child / 'helper.jac');
    }
}

test "mapped debug objects retain reproducible source locations" {
    with TemporaryDirectory() as td {
        base = Path(td).resolve();
        first = emit_object(base / 'debug_first', True, True);
        second = emit_object(base / 'debug_second', True, True);
        assert first == second;
        assert str(base).encode() not in first;
    }
}
