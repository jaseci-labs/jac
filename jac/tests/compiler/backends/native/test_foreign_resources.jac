"""Execute declared foreign cleanup and ABI contracts without CPython type names."""

import ctypes;
import os;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.frontend.unitree { Module }
import from jaclang.compiler.backends.native.llvm { binding as llvm }

test "imported C aliases and function values keep their binding when native names collide" {
    calls: list[int] = [];
    def called(value: int) -> int {
        calls.append(value);
        return value + 10;
    }
    callback = ctypes.CFUNCTYPE(ctypes.c_uint64, ctypes.c_uint64)(called);
    address = ctypes.cast(callback, ctypes.c_void_p).value;
    assert address is not None;
    llvm.add_symbol("foreign_binding_collision", address);
    with tempfile.TemporaryDirectory() as directory {
        (Path(directory) / "bindings.jac").write_text(
            'import from c { @foreign_call(errors="none", reentrant=False) '
            'def foreign_binding_collision(value: u64) -> u64; }'
        );
        program = JacProgram();
        module = program.compile(
            os.path.join(directory, "caller.jac"),
            use_str='import bindings as api; '
                'import from bindings { foreign_binding_collision as imported } '
                'def foreign_binding_collision(value: u64) -> u64 { return wrapping_add(value, 100); } '
                'def probe -> u64 { handler = imported; '
                'return wrapping_add(foreign_binding_collision(1), '
                'wrapping_add(imported(2), wrapping_add(api.foreign_binding_collision(3), handler(4)))); }',
            options=CompileOptions(force_codespace="native", force_target_program=True,
                                   native_required=True, memory_profile="nogc",
                                   no_ir_cache=True, opt_level=0)
        );
        assert not program.errors_had , "\n".join(str(e) for e in program.errors_had);
        assert module is not None and module.gen.native_engine is not None;
        probe = ctypes.CFUNCTYPE(ctypes.c_uint64)(
            module.gen.native_engine.get_function_address("probe")
        );
        assert probe() == 140;
        assert calls == [2, 3, 4];
    }
}

def compile_resource(source: str) -> Module {
    with tempfile.TemporaryDirectory() as directory {
        program = JacProgram();
        module = program.compile(
            os.path.join(directory, "foreign_resource.jac"),
            use_str=source,
            options=CompileOptions(
                force_codespace="native",
                force_target_program=True,
                native_required=True,
                memory_profile="nogc",
                no_ir_cache=True,
                opt_level=0
            )
        );
        assert not program.errors_had , "\n".join(str(e) for e in program.errors_had);
        assert module is not None and module.gen.native_engine is not None;
        assert module.gen.llvm_ir is not None;
        llvm.parse_assembly(str(module.gen.llvm_ir)).verify();
        return module;
    }
}

test "C function pointer fields preserve foreign resource ABI and ownership" {
    for abi in ["pointer", "word"] {
        events: list[int] = [];
        value_type: any = ctypes.c_void_p if abi == "pointer" else ctypes.c_uint64;
        make = ctypes.CFUNCTYPE(value_type, ctypes.c_uint64)(
            lambda (value: int) -> int { value; }
        );
        read = ctypes.CFUNCTYPE(ctypes.c_uint64, value_type)(
            lambda (value: int) -> int { value; }
        );
        drop = ctypes.CFUNCTYPE(None, value_type)(
            lambda (value: int) { events.append(value); }
        );
        drop_address = ctypes.cast(drop, ctypes.c_void_p).value;
        assert drop_address is not None;
        llvm.add_symbol("resource_drop", drop_address);
        table = (ctypes.c_void_p * 3)(
            ctypes.cast(make, ctypes.c_void_p).value,
            ctypes.cast(read, ctypes.c_void_p).value,
            drop_address
        );
        source = f'@foreign_resource(abi="{abi}", empty=47, drop=resource_drop, aliasing="shared", reentrant_drop=True) obj Handle; '
        'import from c { '
        '@foreign_call(errors="none", reentrant=True) def resource_drop(value: own Handle); '
        'obj Api { has make: Callable[[u64], own Handle], '
        'read: Callable[[&Handle], u64], consume: Callable[[own Handle], None]; } } '
        'def probe(api: &Api) -> u64 { owner: own Handle = api.make(11); '
        'owner = api.make(22); api.consume(owner); return api.read(api.make(33)); } '
        'def empty(api: &Api) { owner: own Handle = api.make(47); }';
        module = compile_resource(source);
        engine = module.gen.native_engine;
        assert engine is not None;
        probe = ctypes.CFUNCTYPE(ctypes.c_uint64, ctypes.c_void_p)(
            engine.get_function_address("probe")
        );
        assert probe(table) == 33;
        assert events == [11, 22, 33] , str(events);
        events.clear();
        empty = ctypes.CFUNCTYPE(None, ctypes.c_void_p)(engine.get_function_address("empty"));
        empty(table);
        assert events == [] , str(events);
    }
}

test "declared pointer and word resources use their sentinel and exact drop ABI" {
    for abi in ["pointer", "word"] {
        events: list[int] = [];
        value_type: any = ctypes.c_void_p if abi == "pointer" else ctypes.c_uint64;
        make = ctypes.CFUNCTYPE(value_type, ctypes.c_uint64)(
            lambda (value: int) -> int { value; }
        );
        drop = ctypes.CFUNCTYPE(None, value_type)(
            lambda (value: int) { events.append(value); }
        );
        read = ctypes.CFUNCTYPE(ctypes.c_uint64, value_type)(
            lambda (value: int) -> int { value; }
        );
        for (name, callback) in [
            ("resource_make", make),
            ("resource_drop", drop),
            ("resource_read", read)
        ] {
            address = ctypes.cast(callback, ctypes.c_void_p).value;
            assert address is not None;
            llvm.add_symbol(name, address);
        }
        source = f'@foreign_resource(abi="{abi}", empty=47, drop=resource_drop, aliasing="shared", reentrant_drop=True) obj Handle; '
        'import from c { '
        '@foreign_call(errors="none", reentrant=False) def resource_make(value: u64) -> own Handle; '
        '@foreign_call(errors="none", reentrant=False) def resource_read(value: &Handle) -> u64; '
        '@foreign_call(errors="none", reentrant=True) def resource_drop(value: own Handle); } '
        'def consume(value: own Handle) {} '
        'def probe() -> u64 { value: own Handle = resource_make(11); value = resource_make(22); return resource_read(&value); } '
        'def empty() { value: own Handle = resource_make(47); } '
        'def transfer() { value: own Handle = resource_make(33); consume(value); } '
        'def ffi_transfer() { value: own Handle = resource_make(77); resource_drop(value); } '
        'def ffi_temporary() { resource_drop(resource_make(88)); } '
        'def temporary() -> u64 { return resource_read(resource_make(66)); } '
        'def fail(divisor: int) -> int { value: own Handle = resource_make(44); return 7 // divisor; } '
        'def errors(divisor: int) -> int { try { return fail(divisor); } except ZeroDivisionError { return 99; } } '
        'def peek(value: &Handle) -> &Handle from value { return value; } '
        'def through(handler: &Callable[[value: &Handle], &Handle from value], value: &Handle) -> u64 { '
        'borrowed: &Handle from value = handler(value); return resource_read(borrowed); } '
        'def loans() -> u64 { value: own Handle = resource_make(55); return through(peek, &value); }';
        module = compile_resource(source);
        engine = module.gen.native_engine;
        assert engine is not None;
        probe = ctypes.CFUNCTYPE(ctypes.c_uint64)(engine.get_function_address("probe"));
        empty = ctypes.CFUNCTYPE(None)(engine.get_function_address("empty"));
        transfer = ctypes.CFUNCTYPE(None)(engine.get_function_address("transfer"));
        errors = ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(
            engine.get_function_address("errors")
        );
        assert probe() == 22;
        assert events == [11, 22] , str(events);
        events.clear();
        empty();
        assert events == [] , str(events);
        transfer();
        assert events == [33] , str(events);
        events.clear();
        for (name, expected) in [("ffi_transfer", 77), ("ffi_temporary", 88)] {
            run = ctypes.CFUNCTYPE(None)(engine.get_function_address(name));
            run();
            assert events == [expected] , str(events);
            events.clear();
        }
        temporary = ctypes.CFUNCTYPE(ctypes.c_uint64)(engine.get_function_address("temporary"));
        assert temporary() == 66;
        assert events == [66] , str(events);
        events.clear();
        assert errors(0) == 99;
        assert events == [44] , str(events);
        events.clear();
        loans = ctypes.CFUNCTYPE(ctypes.c_uint64)(engine.get_function_address("loans"));
        assert loans() == 55;
        assert events == [55] , str(events);
        text = str(module.gen.llvm_ir);
        assert "foreign.drop" in text;
        for line in text.splitlines() {
            if line.startswith("define") or line.startswith("declare") {
                if "JacForeign." in line {
                    assert "noalias" not in line and "readonly" not in line , line;
                }
            }
        }
    }
}
