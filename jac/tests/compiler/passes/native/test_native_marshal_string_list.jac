"""Congruence gate for FFI decode of native `list[str]` values.

Every assertion here compares the value the native artifact hands back
through `native_marshal` against the value the sv/bytecode path produces for
the same source, element for element. It pins the string cases that need the
descriptor and header-stamp encoding to be modelled rather than guessed at
with `strlen`: empty lists, empty strings, multi-byte UTF-8, static literals
next to heap strings, slices, an interior NUL, a long list, and -- the case
that had no working path at all -- a `list[str]` read as an object field.
"""

import ctypes;
import os;
import sys;
import types;
import from tests.support { TESTS_DIR, native_force_opts }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes.native.llvm.binding { ExecutionEngine }
import from jaclang.jac0core.codeinfo {
    HDR_ALLOC_ID_OFF,
    HDR_DTOR_OFF,
    HDR_MAGIC,
    HDR_RC_OFF,
    NATIVE_ABI_VERSION,
    RC_SENTINEL,
    str_len_tag
}
import jaclang.jac0core.unitree as uni;

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     ),
     FIXTURE = os.path.join(FIXTURES, "marshal_string_list.jac");

def elem_ptrs(view: any) -> list {
    # The raw i8* element pointers behind a decoded NativeListView, so the
    # length branches can be exercised on addresses native code produced.
    import from jaclang.jac0core.native_marshal { NativeList }
    nl = NativeList.from_address(view.list_ptr);
    return [int(p or 0) for p in (ctypes.c_void_p * len(view)).from_address(nl.data)];
}

def hdr_marks(p: int) -> tuple {
    # (rc-sentinel?, header-magic?, length-tag bit set?, stamped length)
    rc = ctypes.c_uint64.from_address(p + HDR_RC_OFF).value;
    aid = ctypes.c_uint64.from_address(p + HDR_ALLOC_ID_OFF).value;
    dv = ctypes.c_uint64.from_address(p + HDR_DTOR_OFF).value;
    return (rc == RC_SENTINEL, ((aid >> 32) & 0xFFFF) == HDR_MAGIC, dv & 1, dv >> 1);
}

def scratch_str(payload: bytes) -> tuple {
    # A NUL-bounded payload parked far enough into a buffer that the negative
    # header offsets stay inside it, so header reads are observable and safe.
    buf = ctypes.create_string_buffer(256);
    addr = ctypes.addressof(buf) + 128;
    ctypes.memmove(addr, payload + b"\x00", len(payload) + 1);
    return (buf, addr);
}

def poke_u64(addr: int, off: int, value: int) {
    ctypes.memmove(addr + off, ctypes.byref(ctypes.c_uint64(value)), 8);
}

def compile_fixture(fixture: str) -> tuple[ExecutionEngine | None, uni.Module] {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, fixture)), options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    return (ir.gen.native_engine, ir);
}

def native_fns -> dict {
    import from jaclang.jac0core.native_marshal {
        build_ctypes_classes,
        build_enum_maps,
        wrap_native_function,
        init_native_globals
    }
    (eng, ir) = compile_fixture("marshal_string_list.jac");
    layout = ir.gen.native_layout;
    assert layout is not None;
    init_native_globals(eng, ir.gen.interop_manifest);
    ct_classes = build_ctypes_classes(layout);
    enum_maps = build_enum_maps(layout, {});
    fns: dict = {};
    for (fname, func_layout) in layout.functions.items() {
        wrapper = wrap_native_function(
            eng, func_layout, ct_classes, enum_maps, {}, layout=layout
        );
        if wrapper is not None {
            fns[fname] = wrapper;
        }
    }
    return fns;
}

def sv_fns -> dict {
    # The same source through the sv/bytecode backend, executed in a module of
    # its own so the reference values are plain Python objects.
    mod_name = "marshal_string_list_sv_ref";
    code = JacProgram().get_bytecode(FIXTURE);
    assert code is not None , "sv bytecode for the fixture is missing";
    mod = types.ModuleType(mod_name);
    mod.__file__ = FIXTURE;
    sys.modules[mod_name] = mod;
    exec(code, mod.__dict__);
    return mod.__dict__;
}

test "empty list[str] decodes to an empty list" {
    (na, sv) = (native_fns(), sv_fns());
    assert list(na["make_empty"]()) == sv["make_empty"]() == [];
    assert len(na["make_empty"]()) == 0;
}

test "literal list[str] decodes congruently with sv" {
    (na, sv) = (native_fns(), sv_fns());
    expected = sv["make_literals"]();
    got = list(na["make_literals"]());
    assert got == expected , f"{got!r} != {expected!r}";
    # empty string, ASCII, 2-byte and 3-byte UTF-8, and a 64-char string
    assert expected[0] == "" and expected[2] == "über" and expected[3] == "日本語";
    assert len(expected[4]) == 64;
    for (g, e) in zip(got, expected) {
        assert g == e and len(g) == len(e);
    }
}

test "sliced strings decode at their own length" {
    (na, sv) = (native_fns(), sv_fns());
    expected = sv["make_sliced"]();
    assert list(na["make_sliced"]()) == expected == ["abc", "defg", "hij"];
}

test "interior NUL survives the crossing" {
    (na, sv) = (native_fns(), sv_fns());
    expected = sv["make_interior_nul"]();
    got = list(na["make_interior_nul"]());
    assert expected[0] == "a\x00b" , f"sv reference changed: {expected!r}";
    assert got == expected , f"{got!r} != {expected!r}";
}

test "long list[str] decodes element for element" {
    (na, sv) = (native_fns(), sv_fns());
    for n in (0, 1, 2, 33, 257) {
        expected = sv["make_long"](n);
        got = list(na["make_long"](n));
        assert len(got) == n;
        assert got == expected , f"n={n}: {got!r} != {expected!r}";
    }
}

test "list[str] object field decodes to strings not raw pointers" {
    (na, sv) = (native_fns(), sv_fns());
    expected = sv["make_bag"]().tags;
    bag = na["make_bag"]();
    got = list(bag.tags);
    assert all(isinstance(t, str) for t in got) , f"undecoded field: {got!r}";
    assert got == expected , f"{got!r} != {expected!r}";
    assert bag.note == sv["make_bag"]().note;
    assert list(na["bag_tags"]()) == expected;
}

test "dict[str, str] decodes congruently with sv" {
    (na, sv) = (native_fns(), sv_fns());
    expected = sv["make_tag_map"]();
    got = na["make_tag_map"]();
    assert got == expected , f"{got!r} != {expected!r}";
}

test "static literals stamp their length behind the RC sentinel" {
    import from jaclang.jac0core.native_marshal {
        decode_native_str,
        native_stamped_str_len
    }
    (na, sv) = (native_fns(), sv_fns());
    expected = sv["make_interior_nul"]();
    ptrs = elem_ptrs(na["make_interior_nul"]());
    for (p, want) in zip(ptrs, expected) {
        (is_sentinel, is_magic, has_tag, tagged) = hdr_marks(p);
        assert is_sentinel and not is_magic , (
            f"expected the static-literal path, got {hdr_marks(p)}"
        );
        assert has_tag , "static literal carries no length tag";
        assert tagged == len(want.encode("utf-8"));
        assert native_stamped_str_len(p, True) == len(want.encode("utf-8"));
        assert decode_native_str(p, True) == want;
    }
    # the discriminator: strlen stops at the interior NUL, the stamp does not
    assert len(ctypes.string_at(ptrs[0])) == 1;
    assert native_stamped_str_len(ptrs[0], True) == 3;
    # multi-byte literals stamp byte length, not code-point count
    lit_ptrs = elem_ptrs(na["make_literals"]());
    for (p, want) in zip(lit_ptrs[0:4], sv["make_literals"]()[0:4]) {
        assert hdr_marks(p)[0] , "literal element left the sentinel path";
        assert native_stamped_str_len(p, True) == len(want.encode("utf-8"));
    }
    assert native_stamped_str_len(lit_ptrs[3], True) == 9;
}

test "heap strings stamp their length behind the header magic" {
    import from jaclang.jac0core.native_marshal {
        decode_native_str,
        native_stamped_str_len
    }
    (na, sv) = (native_fns(), sv_fns());
    for (p, want) in zip(elem_ptrs(na["make_long"](3)), sv["make_long"](3)) {
        (is_sentinel, is_magic, has_tag, tagged) = hdr_marks(p);
        assert is_magic and not is_sentinel , (
            f"expected the heap-string path, got {hdr_marks(p)}"
        );
        assert has_tag and tagged == len(want.encode("utf-8"));
        assert native_stamped_str_len(p, True) == len(want.encode("utf-8"));
        assert decode_native_str(p, True) == want;
    }
    # a runtime-built literal ("x" * 64) is a heap allocation, not a constant
    built = elem_ptrs(na["make_literals"]())[4];
    assert hdr_marks(built)[1] and not hdr_marks(built)[0];
    assert native_stamped_str_len(built, True) == 64;
    # and the same strlen discriminator on the magic path: a heap string built
    # at runtime around an interior NUL
    heap = sv["make_heap_nul"]();
    assert heap[0] == "a\x00b0" , f"sv reference changed: {heap!r}";
    for (p, want) in zip(elem_ptrs(na["make_heap_nul"]()), heap) {
        assert hdr_marks(p)[1] and not hdr_marks(p)[0] , (
            f"expected the heap-string path, got {hdr_marks(p)}"
        );
        assert len(ctypes.string_at(p)) == 1 , "strlen should stop at the NUL";
        assert native_stamped_str_len(p, True) == 4;
        assert decode_native_str(p, True) == want;
    }
    assert list(na["make_heap_nul"]()) == heap;
}

test "no stamped length falls back to strlen" {
    import from jaclang.jac0core.native_marshal {
        decode_native_str,
        native_stamped_str_len
    }
    assert decode_native_str(0) == "";
    # neither marker present: the bytes before the payload are not a header
    (buf, addr) = scratch_str(b"hello");
    assert hdr_marks(addr) == (False, False, 0, 0);
    assert native_stamped_str_len(addr, True) is None;
    assert decode_native_str(addr, True) == "hello";
    # marker present but the dtor slot holds a real pointer, not a length tag
    poke_u64(addr, HDR_RC_OFF, RC_SENTINEL);
    poke_u64(addr, HDR_DTOR_OFF, 0);
    assert hdr_marks(addr)[0] and not hdr_marks(addr)[2];
    assert native_stamped_str_len(addr, True) is None;
    assert decode_native_str(addr, True) == "hello";
    # and with the tag written the stamped length wins over strlen
    poke_u64(addr, HDR_DTOR_OFF, str_len_tag(3));
    assert native_stamped_str_len(addr, True) == 3;
    assert decode_native_str(addr, True) == "hel";
}

test "a layout that never states str_headerless reads no header" {
    import from jaclang.jac0core.native_dylib { layout_from_dict }
    import from jaclang.jac0core.native_marshal {
        decode_native_str,
        layout_str_header_stamped,
        native_stamped_str_len
    }
    # A sealed artifact predating the str_headerless key. Under --gc none its
    # strings are genuinely headerless, so trusting a headerful default would
    # read allocation memory that is not a header.
    legacy = layout_from_dict({"abi_version": NATIVE_ABI_VERSION});
    assert legacy.str_headerless is None;
    assert layout_str_header_stamped(legacy) == False;
    # poison the header region with a plausible sentinel and a bogus length:
    # only a decoder that reads the header can report anything but "hello"
    (buf, addr) = scratch_str(b"hello");
    poke_u64(addr, HDR_RC_OFF, RC_SENTINEL);
    poke_u64(addr, HDR_DTOR_OFF, str_len_tag(200));
    assert native_stamped_str_len(addr, layout_str_header_stamped(legacy)) is None;
    assert decode_native_str(addr, layout_str_header_stamped(legacy)) == "hello";
    # the default argument is the same conservative choice
    assert decode_native_str(addr) == "hello";
    # an artifact that does state it keeps the stamped read
    headerful = layout_from_dict(
        {"abi_version": NATIVE_ABI_VERSION, "str_headerless": False}
    );
    assert layout_str_header_stamped(headerful) == True;
    assert native_stamped_str_len(addr, layout_str_header_stamped(headerful)) == 200;
    nogc = layout_from_dict(
        {"abi_version": NATIVE_ABI_VERSION, "str_headerless": True}
    );
    assert layout_str_header_stamped(nogc) == False;
    assert native_stamped_str_len(addr, layout_str_header_stamped(nogc)) is None;
    assert decode_native_str(addr, layout_str_header_stamped(nogc)) == "hello";
}

test "the jit layout states its header mode" {
    import from jaclang.jac0core.native_marshal { layout_str_header_stamped }
    (eng, ir) = compile_fixture("marshal_string_list.jac");
    layout = ir.gen.native_layout;
    assert layout.str_headerless == False , (
        "an rc-mode artifact must record that its strings carry a header"
    );
    assert layout_str_header_stamped(layout) == True;
}
