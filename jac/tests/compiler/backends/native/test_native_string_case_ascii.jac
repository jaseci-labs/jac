import ctypes;
import os;
import re;
import tempfile;
import from pathlib { Path }
import from tests.support {
    NATIVE_FIXTURES,
    compile_native_ir,
    names_function,
    native_build,
    native_run,
    native_str_func,
    remember_native_unit
}
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.backends.native.llvm { binding as llvm, ir }

glob FIXTURE = str(Path(NATIVE_FIXTURES) / "string_case_ascii.jac"),
     _CALLBACK_ENGINES: list[tuple[any, any, any]] = [];

def compile_case -> any {
    program = JacProgram();
    module = program.compile(
        file_path=FIXTURE,
        options=CompileOptions(force_codespace="native", no_ir_cache=True)
    );
    assert not program.errors_had , [e.pretty_print() for e in program.errors_had];
    engine = module.gen.native_engine;
    assert engine is not None;
    remember_native_unit(engine, module);
    return engine;
}

def checker(engine: any) -> any {
    return native_str_func(
        engine,
        "check_case",
        ctypes.c_int64,
        ctypes.c_char_p,
        ctypes.c_char_p,
        ctypes.c_int64,
        ctypes.c_bool
    );
}

test "native case conversion preserves every byte and output metadata" {
    engine = compile_case();
    check = checker(engine);
    library = ctypes.CDLL(None);
    for size in [0, 1, 1023, 1024, 1025, 4096] {
        payload = bytes(i % 128 for i in range(size));
        for mode in range(3) {
            mapper = library.toupper if mode == 1 else library.tolower;
            expected = bytes(mapper(point) & 255 for point in payload);
            assert check(payload, expected, mode, expected.isascii()) == 0 , (
                size,
                mode
            );
        }
    }
    for text in ["AéΣİ🙂\x00Z", "AéΣİ🙂\x00Z" * 200] {
        payload = text.encode();
        for mode in range(3) {
            mapper = library.toupper if mode == 1 else library.tolower;
            expected = bytes(mapper(point) & 255 for point in payload);
            assert check(payload, expected, mode, expected.isascii()) == 0 , (
                text,
                mode
            );
        }
    }
    view = native_str_func(
        engine, "check_view", ctypes.c_int64, ctypes.c_char_p, ctypes.c_char_p
    );
    assert view(b"!" + b"A\x00Z" * 1024 + b"?", b"a\x00z" * 1024) == 0;
}

test "ASCII fast path rechecks the active C mapping and keeps short calls scalar" {
    library = ctypes.CDLL(None);
    callback_type = ctypes.CFUNCTYPE(ctypes.c_int32, ctypes.c_int32);
    changed: list[bool] = [False];
    calls: list[int] = [0, 0];
    def lower(point: int) -> int {
        calls[0] += 1;
        if changed[0] and point == 73 {
            return 253;
        }
        return point + 32 if 65 <= point <= 90 else point;
    }
    def upper(point: int) -> int {
        calls[1] += 1;
        if changed[0] and point == 105 {
            return 221;
        }
        return point - 32 if 97 <= point <= 122 else point;
    }
    lower_callback = callback_type(lower);
    upper_callback = callback_type(upper);
    try {
        llvm.add_symbol("tolower", ctypes.cast(lower_callback, ctypes.c_void_p).value);
        llvm.add_symbol("toupper", ctypes.cast(upper_callback, ctypes.c_void_p).value);
        engine = compile_case();
        _CALLBACK_ENGINES.append((engine, lower_callback, upper_callback));
        check = checker(engine);
        for mode in range(3) {
            slot = 1 if mode == 1 else 0;
            for size in [1, 1023, 1024, 1025, 4096] {
                payload = (b"IiAaZz!" * (size // 7 + 1))[:size];
                expected = payload.upper() if mode == 1 else payload.lower();
                calls[slot] = 0;
                assert check(payload, expected, mode, True) == 0;
                if size < 1024 {
                    assert calls[slot] == size , (size, mode, calls);
                } else {
                    assert 0 < calls[slot] <= 128 , (size, mode, calls);
                }
            }
            payload = b"\xc3\xa9 AaZz!\x00" * 200;
            expected = payload.upper() if mode == 1 else payload.lower();
            calls[slot] = 0;
            assert check(payload, expected, mode, False) == 0;
            assert calls[slot] == len(payload) , (mode, calls);
        }
        changed[0] = True;
        for mode in range(3) {
            for repeats in [1, 127, 128, 200] {
                payload = b"IiAaZz!\x00" * repeats;
                expected = (b"I\xddAAZZ!\x00" if mode == 1 else b"\xfdiaazz!\x00")
                    * repeats;
                slot = 1 if mode == 1 else 0;
                calls[slot] = 0;
                assert check(payload, expected, mode, False) == 0;
                if len(payload) < 1024 {
                    assert calls[slot] == len(payload) , (mode, repeats, calls);
                } else {
                    guard_calls = 106 if mode == 1 else 74;
                    assert calls[slot] == len(payload) + guard_calls , (
                        mode,
                        repeats,
                        calls
                    );
                }
            }
        }
    } finally {
        llvm.add_symbol("tolower", ctypes.cast(library.tolower, ctypes.c_void_p).value);
        llvm.add_symbol("toupper", ctypes.cast(library.toupper, ctypes.c_void_p).value);
    }
}

test "case fast helpers are shared and reject without writing" {
    module = compile_native_ir("string_case_ascii.jac");
    text = str(module.gen.llvm_ir);
    for name in ["__jac_str_case_tolower", "__jac_str_case_toupper"] {
        definitions = [
            line
            for line in text.splitlines()
            if line.startswith("define ") and names_function(line, name)
        ];
        assert len(definitions) == 1 , definitions;
        fn = module.gen.llvm_ir.globals[name];
        assert isinstance(fn, ir.Function);
        predecessors: dict[str, list[str]] = {block.name: [] for block in fn.blocks};
        rejecting: list[str] = [];
        accepting: list[str] = [];
        for block in fn.blocks {
            term = block.terminator;
            assert isinstance(term, ir.Instruction);
            if term.opname == "ret" {
                value = term.operands[0];
                assert isinstance(value, ir.Constant) and value.constant in [0, 1];
                (rejecting if value.constant == 0 else accepting).append(block.name);
            } else {
                assert term.opname == "br" , term;
                for successor in term.operands {
                    if isinstance(successor, ir.Block) {
                        predecessors[successor.name].append(block.name);
                    }
                }
            }
            # Guards may inspect the source, but may not pass the destination
            # (or a derived pointer) to a callee that could write to it.
            for instruction in block.instructions {
                if isinstance(instruction, ir.CallInstr) {
                    for argument in instruction.args {
                        if isinstance(argument.type, ir.PointerType) {
                            assert argument is fn.args[0] , instruction;
                        }
                    }
                }
            }
        }
        assert rejecting and accepting;
        pending = rejecting.copy();
        can_reject: set[str] = set();
        while pending {
            current = pending.pop();
            if current not in can_reject {
                can_reject.add(current);
                pending.extend(predecessors[current]);
            }
        }
        stores = [
            block.name for block in fn.blocks
            for instruction in block.instructions
            if isinstance(instruction, ir.StoreInstr)
        ];
        assert stores;
        assert not (set(stores) & can_reject) , (name, stores, can_reject);
    }
}

test "case conversion releases outputs in RC and managed builds" {
    for memory in ["rc", "managed"] {
        with tempfile.TemporaryDirectory() as tmp {
            binary = os.path.join(tmp, "string_case_ascii");
            native_build(FIXTURE, binary, memory=memory, extra=["--debug"]);
            output = native_run(binary);
        }
        assert output.splitlines()[-1] == "1";
        allocated = set(
            re.findall(r"RC MALLOC\s+id=(\d+)\s.*\bop=upper_lower\b", output)
        );
        freed = set(re.findall(r"RC FREE\s+id=(\d+)\s", output));
        assert allocated , output[-2000:];
        assert not (allocated - freed) , (memory, allocated - freed);
    }
}
