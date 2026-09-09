"""List construction preserves tuple values and owns each copied element."""
import ctypes;
import os;
import subprocess;
import tempfile;
import from jaclang.compiler.backends.native.lowering { native_lowering_issues }
import from tests.support {
    compile_native,
    get_func,
    native_build,
    NATIVE_FIXTURES,
    NATIVE_MEMORY_PROFILES
}

test "list constructs scalar and mixed tuple elements in order" {
    (engine, module) = compile_native("tuple_list_conversion.jac");
    assert not native_lowering_issues(str(module.gen.llvm_ir));
    call = get_func(engine, "scalars", ctypes.c_int64);
    actual = call();
    assert actual == 25 , actual;
}

test "list retains fresh and returned tuple objects exactly once" {
    (engine, module) = compile_native("tuple_list_conversion.jac");
    assert not native_lowering_issues(str(module.gen.llvm_ir));
    drops = get_func(engine, "drops", ctypes.c_int64);
    for (name, expected) in [("fresh_objects", 10), ("returned_objects", 11)] {
        call = get_func(engine, name, ctypes.c_int64);
        before = drops();
        assert call() == expected;
        assert drops() - before == 2 , name;
    }
}

test "list shares borrowed tuple objects and releases both references" {
    (engine, module) = compile_native("tuple_list_shared.jac");
    assert not native_lowering_issues(str(module.gen.llvm_ir));
    drops = get_func(engine, "shared_drops", ctypes.c_int64);
    call = get_func(engine, "borrowed_objects", ctypes.c_int64);
    before = drops();
    assert call() == 17;
    assert drops() - before == 2;
}

test "tuple conversion preserves empty and widened list storage" {
    (engine, module) = compile_native("tuple_list_context.jac");
    issues = native_lowering_issues(str(module.gen.llvm_ir));
    assert not issues , str(issues);
    for (name, expected) in [("empty_lists", 43), ("widened_elements", 6)] {
        call = get_func(engine, name, ctypes.c_int64);
        actual = call();
        assert actual == expected , f"{name}: {actual}";
    }
}

test "tuple list construction runs in every native memory profile" {
    with tempfile.TemporaryDirectory() as directory {
        for memory in NATIVE_MEMORY_PROFILES {
            binary = os.path.join(directory, memory);
            native_build(
                os.path.join(NATIVE_FIXTURES, "tuple_list_conversion.jac"),
                binary,
                memory=memory
            );
            result = subprocess.run(
                [binary], capture_output=True, text=True, timeout=30
            );
            assert result.returncode == 0 , result.stderr;
            assert result.stdout.splitlines() == ["25", "10", "11", "4"] , (
                memory + ": " + result.stdout
            );
        }
    }
}
