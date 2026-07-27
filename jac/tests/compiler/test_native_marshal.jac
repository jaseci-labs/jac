"""Tests for native_marshal.jac: ctypes marshalling infrastructure.

Tests NativeFieldInfo metadata, build_ctypes_classes, _build_cfunctype,
and NativeStructView/NativeListView with function pointer fields.
"""

import ctypes;
import from jaclang.jac0core.codeinfo {
    NativeFieldInfo,
    NativeStructLayout,
    NativeModuleLayout
}
import from jaclang.jac0core.native_marshal {
    _build_cfunctype,
    build_ctypes_classes,
    build_enum_maps,
    NativeStructView,
    NativeListView,
    LLVM_TO_CTYPES,
    marshal_value
}

# ── NativeFieldInfo: func_ptr metadata ───────────────────────
test "NativeFieldInfo defaults is_func_ptr to False" {
    fi = NativeFieldInfo(name="x", llvm_type="i64", index=0);
    assert fi.is_func_ptr == False;
    assert fi.func_param_types is None;
    assert fi.func_ret_type is None;
}

test "NativeFieldInfo stores func_ptr metadata" {
    fi = NativeFieldInfo(
        name="callback",
        llvm_type="ptr",
        index=0,
        is_func_ptr=True,
        func_param_types=["i64", "i64"],
        func_ret_type="i64"
    );
    assert fi.is_func_ptr == True;
    assert fi.func_param_types == ["i64", "i64"];
    assert fi.func_ret_type == "i64";
}

test "NativeFieldInfo enum_type and func_ptr are independent" {
    fi = NativeFieldInfo(name="color", llvm_type="i64", index=0, enum_type="Color");
    assert fi.enum_type == "Color";
    assert fi.is_func_ptr == False;
}

# ── _build_cfunctype ─────────────────────────────────────────
test "build_cfunctype with i64 params and return" {
    fi = NativeFieldInfo(
        name="cb",
        llvm_type="ptr",
        index=0,
        is_func_ptr=True,
        func_param_types=["i64", "i64"],
        func_ret_type="i64"
    );
    ft = _build_cfunctype(fi);
    assert ft is not None;
    # CFUNCTYPE returns a class
    assert callable(ft);
}

test "build_cfunctype with void return" {
    fi = NativeFieldInfo(
        name="cb",
        llvm_type="ptr",
        index=0,
        is_func_ptr=True,
        func_param_types=["i64"],
        func_ret_type="void"
    );
    ft = _build_cfunctype(fi);
    assert ft is not None;
}

test "build_cfunctype with no params" {
    fi = NativeFieldInfo(
        name="cb",
        llvm_type="ptr",
        index=0,
        is_func_ptr=True,
        func_param_types=[],
        func_ret_type="f64"
    );
    ft = _build_cfunctype(fi);
    assert ft is not None;
}

test "build_cfunctype with mixed param types" {
    fi = NativeFieldInfo(
        name="cb",
        llvm_type="ptr",
        index=0,
        is_func_ptr=True,
        func_param_types=["i64", "f64", "i8*"],
        func_ret_type="i1"
    );
    ft = _build_cfunctype(fi);
    assert ft is not None;
}

# ── build_ctypes_classes ─────────────────────────────────────
test "build_ctypes_classes produces Structure for simple struct" {
    layout = NativeModuleLayout(
        structs={
            "Point": NativeStructLayout(
                name="Point",
                fields=[
                    NativeFieldInfo(name="x", llvm_type="i64", index=0),
                    NativeFieldInfo(name="y", llvm_type="i64", index=1)
                ]
            )
        }
    );
    classes = build_ctypes_classes(layout);
    assert "Point" in classes;
    cls = classes["Point"];
    assert issubclass(cls, ctypes.Structure);
    # Verify field names
    field_names = [f[0] for f in cls._fields_];
    assert field_names == ["x", "y"];
}

test "build_ctypes_classes maps func_ptr fields to c_void_p" {
    layout = NativeModuleLayout(
        structs={
            "Handler": NativeStructLayout(
                name="Handler",
                fields=[
                    NativeFieldInfo(name="value", llvm_type="i64", index=0),
                    NativeFieldInfo(
                        name="callback",
                        llvm_type="ptr",
                        index=1,
                        is_func_ptr=True,
                        func_param_types=["i64"],
                        func_ret_type="i64"
                    )
                ]
            )
        }
    );
    classes = build_ctypes_classes(layout);
    cls = classes["Handler"];
    field_types = {f[0]: f[1] for f in cls._fields_};
    assert field_types["value"] == ctypes.c_int64;
    assert field_types["callback"] == ctypes.c_void_p;
}

test "build_ctypes_classes maps string fields to c_void_p" {
    layout = NativeModuleLayout(
        structs={
            "Named": NativeStructLayout(
                name="Named",
                fields=[NativeFieldInfo(name="name", llvm_type="i8*", index=0)]
            )
        }
    );
    classes = build_ctypes_classes(layout);
    cls = classes["Named"];
    field_types = {f[0]: f[1] for f in cls._fields_};
    # i8* should be c_void_p (not c_char_p) to avoid auto-copy
    assert field_types["name"] == ctypes.c_void_p;
}

# ── marshal_value: func_ptr handling ─────────────────────────
test "marshal_value returns None for null func_ptr" {
    fi = NativeFieldInfo(
        name="cb",
        llvm_type="ptr",
        index=0,
        is_func_ptr=True,
        func_param_types=["i64"],
        func_ret_type="i64"
    );
    result = marshal_value(0, "ptr", {}, {}, {}, field_info=fi);
    assert result is None;
}

test "marshal_value returns None for None func_ptr" {
    fi = NativeFieldInfo(
        name="cb",
        llvm_type="ptr",
        index=0,
        is_func_ptr=True,
        func_param_types=["i64"],
        func_ret_type="i64"
    );
    result = marshal_value(None, "ptr", {}, {}, {}, field_info=fi);
    assert result is None;
}

# ── LLVM_TO_CTYPES mapping ──────────────────────────────────
test "LLVM_TO_CTYPES contains all standard mappings" {
    assert LLVM_TO_CTYPES["i64"] == ctypes.c_int64;
    assert LLVM_TO_CTYPES["i32"] == ctypes.c_int32;
    assert LLVM_TO_CTYPES["i16"] == ctypes.c_int16;
    assert LLVM_TO_CTYPES["i8"] == ctypes.c_int8;
    assert LLVM_TO_CTYPES["i1"] == ctypes.c_bool;
    assert LLVM_TO_CTYPES["f64"] == ctypes.c_double;
    assert LLVM_TO_CTYPES["f32"] == ctypes.c_float;
    assert LLVM_TO_CTYPES["i8*"] == ctypes.c_char_p;
    assert LLVM_TO_CTYPES["void"] is None;
}

# ── identity dedup + cycle safety ────────────────────────────
def _pair_layout -> NativeModuleLayout {
    return NativeModuleLayout(
        structs={
            "Child": NativeStructLayout(
                name="Child",
                fields=[NativeFieldInfo(name="val", llvm_type="i64", index=0)]
            ),
            "Pair": NativeStructLayout(
                name="Pair",
                fields=[
                    NativeFieldInfo(name="left", llvm_type="Child*", index=0),
                    NativeFieldInfo(name="right", llvm_type="Child*", index=1)
                ]
            )
        }
    );
}

def _node_layout -> NativeModuleLayout {
    return NativeModuleLayout(
        structs={
            "Node": NativeStructLayout(
                name="Node",
                fields=[
                    NativeFieldInfo(name="val", llvm_type="i64", index=0),
                    NativeFieldInfo(name="nxt", llvm_type="Node*", index=1)
                ]
            )
        }
    );
}

test "marshal_value dedups shared struct pointers" {
    layout = _pair_layout();
    classes = build_ctypes_classes(layout);
    child = classes["Child"]();
    child.val = 7;
    pair = classes["Pair"]();
    pair.left = ctypes.addressof(child);
    pair.right = ctypes.addressof(child);
    v = marshal_value(ctypes.addressof(pair), "Pair*", classes, {}, {}, layout=layout);
    assert v.left is v.left;
    assert v.left is v.right;
    assert v.left == v.right;
    assert len({v.left, v.right}) == 1;
    assert v.left.val == 7;
}

test "marshal_value closes cyclic struct graphs" {
    layout = _node_layout();
    classes = build_ctypes_classes(layout);
    a = classes["Node"]();
    b = classes["Node"]();
    a.val = 1;
    b.val = 2;
    a.nxt = ctypes.addressof(b);
    b.nxt = ctypes.addressof(a);
    v = marshal_value(ctypes.addressof(a), "Node*", classes, {}, {}, layout=layout);
    assert v.nxt.nxt is v;
    assert v.nxt.nxt == v;
    assert v.nxt.val == 2;
}

test "struct view scalar write goes through to native memory" {
    layout = _pair_layout();
    classes = build_ctypes_classes(layout);
    child = classes["Child"]();
    child.val = 7;
    v = marshal_value(
        ctypes.addressof(child), "Child*", classes, {}, {}, layout=layout
    );
    v.val = 99;
    assert child.val == 99;
    fresh = marshal_value(
        ctypes.addressof(child), "Child*", classes, {}, {}, layout=layout
    );
    assert fresh.val == 99;
}

test "struct view write rejects pointer fields and unknown names" {
    layout = _pair_layout();
    classes = build_ctypes_classes(layout);
    child = classes["Child"]();
    pair = classes["Pair"]();
    pair.left = ctypes.addressof(child);
    pair.right = ctypes.addressof(child);
    v = marshal_value(ctypes.addressof(pair), "Pair*", classes, {}, {}, layout=layout);
    got_type_error = False;
    try {
        v.left = 0;
    } except TypeError {
        got_type_error = True;
    }
    assert got_type_error;
    got_attr_error = False;
    try {
        v.missing = 1;
    } except AttributeError {
        got_attr_error = True;
    }
    assert got_attr_error;
}
