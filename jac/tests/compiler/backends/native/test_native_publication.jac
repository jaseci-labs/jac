import os;
import subprocess;
import tempfile;
import from pathlib { Path }
import from unittest.mock { patch }
import jaclang.jac0core.cache_paths as cache_paths;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.backends.native.link_plan {
    ArtifactKind,
    build_link_plan,
    link_artifact
}

test "failed atomic publication preserves the destination and removes its temporary file" {
    with tempfile.TemporaryDirectory() as directory {
        target = Path(directory) / "product";
        target.write_bytes(b"previous product");
        failed = False;
        with patch.object(
            cache_paths.os, "replace", side_effect=OSError("publication failed")
        ) {
            try {
                cache_paths.atomic_write(target, b"replacement product");
            } except OSError {
                failed = True;
            }
        }
        assert failed;
        assert target.read_bytes() == b"previous product";
        assert list(Path(directory).iterdir()) == [target];
    }
}

test "atomic publication preserves existing file permissions" {
    if os.name == "nt" {
        return;
    }
    with tempfile.TemporaryDirectory() as directory {
        target = Path(directory) / "private_cache";
        target.write_bytes(b"old");
        target.chmod(0o640);
        cache_paths.atomic_write(target, b"new");
        assert target.read_bytes() == b"new";
        assert target.stat().st_mode & 0o777 == 0o640;
    }
}

test "rebuilding a native executable preserves its open previous image" {
    if os.name == "nt" {
        return;
    }
    with tempfile.TemporaryDirectory() as directory {
        source = Path(directory) / "main.jac";
        output = Path(directory) / "program";
        source.write_text("with entry { print(7); }\n");
        options = CompileOptions(
            aot_mode=True,
            default_codespace="native",
            skip_native_engine=True,
            memory_profile="nogc"
        );
        first = JacProgram();
        first.options = options;
        plan = build_link_plan(first, [str(source)], options);
        link_artifact(plan, str(output), ArtifactKind.EXECUTABLE);
        original = output.read_bytes();
        with output.open("rb") as previous {
            source.write_text("with entry { print(8); }\n");
            second = JacProgram();
            second.options = options;
            replacement = build_link_plan(second, [str(source)], options);
            link_artifact(replacement, str(output), ArtifactKind.EXECUTABLE);
            assert output.read_bytes() != original;
            assert previous.read() == original , "rebuilding changed an already-open executable image";
            assert os.fstat(previous.fileno()).st_ino != output.stat().st_ino;
        }
        result = subprocess.run([str(output)], capture_output=True, text=True);
        assert result.returncode == 0 , result.stderr;
        assert result.stdout.strip() == "8";
    }
}


test "new atomic products follow the process umask" {
    if os.name == "nt" {
        import pytest;
        pytest.skip("POSIX permissions");
    }
    with tempfile.TemporaryDirectory() as directory {
        target = Path(directory) / "product";
        previous = os.umask(0o022);
        try {
            cache_paths.atomic_write(target, b"public product");
        } finally {
            os.umask(previous);
        }
        assert target.stat().st_mode & 0o777 == 0o644;
    }
}

test "a bytecode compile preserves every stamped native product" {
    import from jaclang.compiler.driver.jir {
        SEC_NIFACE,
        SEC_NOBJ,
        SEC_NBITCODE,
        SEC_NDEPS,
        SEC_NCTDEPS,
        SEC_BYTECODE,
        get_module_cache_path,
        read_section_bytes,
        native_section_payload
    }
    with tempfile.TemporaryDirectory() as directory {
        source = Path(directory) / "main.jac";
        (Path(directory) / "jac.toml").write_text('[placement]\ndefault = "server"\n');
        source.write_text("def answer -> int { return 42; }\n");
        program = JacProgram();
        options = CompileOptions(
            aot_mode=True, default_codespace="native", skip_native_engine=True
        );
        plan = build_link_plan(program, [str(source)], options);
        program.native_units().object_for(str(source), options);
        cache = get_module_cache_path(str(source));
        before = cache.read_bytes();
        stamp = program.native_units().stamp_for(options);
        sections = [SEC_NIFACE, SEC_NOBJ, SEC_NBITCODE, SEC_NDEPS, SEC_NCTDEPS];
        assert all(
            read_section_bytes(before, section) is not None for section in sections
        );
        bytecode_program = JacProgram();
        bytecode = program._get_compiler().get_bytecode(str(source), bytecode_program);
        assert bytecode is not None;
        after = cache.read_bytes();
        assert read_section_bytes(after, SEC_BYTECODE) is not None;
        for section in sections {
            assert native_section_payload(read_section_bytes(after, section), stamp)
                == native_section_payload(read_section_bytes(before, section), stamp) , f"native section {section} changed";
        }
    }
}

test "suppressed module lowering failures retain their cause" {
    import from jaclang.compiler.backends.native.na_ir_gen_pass { NaIRGenPass }
    import from jaclang.compiler.frontend.diagnostics { E5092 }
    original: any = NaIRGenPass._codegen_entry;
    def fail_entry(pass_: any, nodes: any) {
        original(pass_, nodes);
        pass_.emit(E5092, kind="test operation", name="unlowerable_entry");
    }
    with tempfile.TemporaryDirectory() as directory {
        source = Path(directory) / "main.jac";
        source.write_text("with entry { print(42); }\n");
        program = JacProgram();
        options = CompileOptions(
            aot_mode=True,
            default_codespace="native",
            skip_native_engine=True,
            suppress_codes=["E5092"]
        );
        with patch.object(NaIRGenPass, "_codegen_entry", fail_entry) {
            unit_entry = program.native_units().compile_unit(str(source), options);
        }
        assert unit_entry is None;
        failure = program.native_units().failures[str(source.resolve())];
        assert "unlowerable_entry" in failure , failure;
        assert "E5092" in failure , failure;
    }
}

test "in-memory native source overrides never reuse disk products" {
    import ctypes;
    with tempfile.TemporaryDirectory() as directory {
        source = Path(directory) / "main.jac";
        source.write_text("def answer -> int { return 7; }\n");
        program = JacProgram();
        build_options = CompileOptions(
            aot_mode=True, default_codespace="native", skip_native_engine=True
        );
        build_link_plan(program, [str(source)], build_options);
        options = CompileOptions(force_codespace="native");
        changed = JacProgram().compile(
            str(source), use_str="def answer -> int { return 42; }\n", options=options
        );
        assert not options.no_ir_cache;
        assert changed.gen.native_iface is not None;
        assert changed.gen.native_engine is not None;
        symbol = changed.gen.native_iface.symbol_of("answer");
        assert symbol is not None;
        address = changed.gen.native_engine.get_function_address(symbol);
        assert address;
        assert ctypes.CFUNCTYPE(ctypes.c_int64)(address)() == 42;
    }
}
