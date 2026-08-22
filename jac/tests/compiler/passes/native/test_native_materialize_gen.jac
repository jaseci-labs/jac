"""The materializer generator must emit only what it can actually build.

`gen_native_materialize` turns the sealed unitree layout into the emitters that
rebuild a native parse tree as CPython objects. A dict field crosses as a
`PyDict_New` plus one key conversion per entry, and that conversion has to match
the field's declared key type: the emitted `native_materialize.jac` is compiled
like any other module, so a key converted with the wrong extern is a hard
`E1053` on the generated source -- 456 of them when `type` gained a native
representation (#8161) and `UniNode.__sub_node_tab`, a `dict[type, ...]`, stopped
being layout-erased. The generator had been coercing every non-scalar key type
to `int`, which was invisible only while no such dict reached a layout.

A list field has the same shape of failure and the same cause. Elements were
emitted through `_emit_node` whenever the generator did not recognize their
type, which types the call against `UniNode`; that was invisible while every
list slot in a layout held nodes. `Ability.event_triggers` is
`list[TypeBase]`, and it reached a layout the moment the type system joined
the sealed closure -- E1053 on the generated source, with ten artifacts
already emitted behind it.

These tests drive `generate` directly with a synthetic layout, so they measure
the emitter without a native compile or a seal. The last one is the general
gate: it sweeps every field of every class the profile knows and fails if any
emitted key conversion disagrees with the annotation it was generated from, so
the next key type to gain a native representation cannot reopen this.
"""

import tempfile;
import from pathlib { Path }
import from dataclasses { fields as dc_fields, is_dataclass }
import jaclang.jac0core.srcloc as srcloc;
import jaclang.jac0core.unitree as uni;
import from jaclang.utils.gen_native_materialize {
    generate,
    _inner,
    _norm,
    _split_kv,
    _split_union
}

"""Key-conversion externs, mapped to the only declared key type each is valid for."""
glob KEY_CTORS: dict[(str, str)] = {
         "PyLong_FromLongLong(dk_": "int",
         "_py_str(dk_": "str",
         "PyFloat_FromDouble(dk_": "float",
         "PyBool_FromLong(1 if dk_": "bool"
     },
     _GEN_MEMO: dict = {};

"""The layout's name for a dataclass field, un-mangling a private one."""
def _layout_name(fname: str) -> str {
    if fname.startswith("_") and "__" in fname[1:] {
        return fname[fname.index("__", 1):];
    }
    return fname;
}

"""Generate the materializer root from a synthetic layout: {class: [field, ...]}."""
def _gen(specs: dict[(str, list[str])]) -> tuple[(str, dict)] {
    memo_key = repr(sorted(specs.items()));
    if memo_key in _GEN_MEMO {
        return _GEN_MEMO[memo_key];
    }
    structs: dict = {};
    for (cname, fnames) in specs.items() {
        structs[cname] = {"fields": [{"name": fn} for fn in fnames]};
    }
    out_jac = Path(tempfile.mkdtemp(prefix="jac_matgen_")) / "native_materialize.jac";
    manifest = generate({"structs": structs}, out_jac, ());
    result = (out_jac.read_text(encoding="utf-8"), manifest, );
    _GEN_MEMO[memo_key] = result;
    return result;
}

"""One emitter function's body, sliced out of the generated module."""
def _emit_fn(txt: str, cname: str) -> str {
    marker = f"def _emit_{cname}(";
    start = txt.index(marker);
    return txt[start:txt.index("\n}", start)];
}

"""Every (annotation, emitted body) pair, keyed off the generator's field comments."""
def _field_blocks(txt: str) -> list[tuple[(str, str)]] {
    blocks: list[tuple[(str, str)]] = [];
    lines = txt.split("\n");
    cur_ann: (str | None) = None;
    cur: list[str] = [];
    for line in lines {
        if line.startswith("    # ") and ": " in line {
            if cur_ann is not None {
                blocks.append((cur_ann, "\n".join(cur), ));
            }
            cur_ann = line.split(": ", 1)[1];
            cur = [];
        } elif cur_ann is not None {
            cur.append(line);
        }
    }
    if cur_ann is not None {
        blocks.append((cur_ann, "\n".join(cur), ));
    }
    return blocks;
}

"""The declared key type of a dict annotation, or '' when it is not a dict."""
def _dict_key_type(ann: str) -> str {
    arms = [
        a
        for a in _split_union(_norm(ann))
        if a != "None"
    ];
    if len(arms) != 1 {
        return "";
    }
    arm = _norm(arms[0]);
    if not arm.startswith("dict[") {
        return "";
    }
    return _split_kv(_inner(arm))[0];
}

"""Every class the profile's modules define, with all of its layout field names."""
def _all_fields -> dict[(str, list[str])] {
    out: dict[(str, list[str])] = {};
    for mod in (uni, srcloc) {
        for (cname, cls) in vars(mod).items() {
            if isinstance(cls, type)
                and getattr(cls, "__module__", "") == mod.__name__
                and is_dataclass(cls) {
                out[cname] = [_layout_name(f.name) for f in dc_fields(cls)];
            }
        }
    }
    return out;
}


test "a dict keyed by a type is erased, never converted as an int key" {
    (txt, _m) = _gen({"UniNode": ["__sub_node_tab"]});
    body = _emit_fn(txt, "UniNode");
    assert "PyLong_FromLongLong" not in body , (
        "UniNode.__sub_node_tab is dict[type, list[UniNode]]; converting its "
        "key with PyLong_FromLongLong is the #8161 seal break (E1053 on the "
        "generated native_materialize.jac):\n"
        + body
    );
    assert "_py_none()" in body , (
        "a key type with no materializer must erase the whole field to None -- "
        "a dict cannot be rebuilt without its keys:\n"
        + body
    );
    assert "PyDict_New" not in body , (
        "the field was still emitted as a dict despite an unbuildable key:\n" + body
    );
}


test "erasing a slot is reported, not silent" {
    (_txt, manifest) = _gen({"UniNode": ["__sub_node_tab"]});
    warns = [
        w
        for w in manifest["warnings"]
        if "type" in w
    ];
    assert warns , (
        "the generator dropped a field it could not materialize without saying "
        f"so; warnings were {manifest['warnings']}"
    );
}


test "the native slot of an erased field is never even read" {
    (txt, _m) = _gen({"UniNode": ["__sub_node_tab"]});
    body = _emit_fn(txt, "UniNode");
    assert "nd.__sub_node_tab" not in body , (
        "an erased field must not load its native slot: the read is dead, and "
        "it drags a type the emitter already declined into the sealed unit:\n"
        + body
    );
}


test "a list of non-node elements is erased, never emitted through the node chain" {
    (txt, _m) = _gen({"Ability": ["event_triggers"]});
    body = _emit_fn(txt, "Ability");
    assert "_emit_node(" not in body , (
        "Ability.event_triggers is list[TypeBase] | None, and TypeBase is not "
        "on the node chain. Emitting its elements through `_emit_node` types "
        "the call against UniNode and the generated root refuses to compile "
        "(E1053), which is what the type system joining the sealed closure "
        "made reachable:\n"
        + body
    );
    assert "_py_none()" in body , (
        "an element type with no emitter must erase the whole field to None:\n" + body
    );
    assert "PyList_New" not in body , (
        "the field was still emitted as a list despite an element the "
        "generator cannot build:\n"
        + body
    );
}


test "erasing a list element type is reported, not silent" {
    (_txt, manifest) = _gen({"Ability": ["event_triggers"]});
    warns = [
        w
        for w in manifest["warnings"]
        if "element" in w
    ];
    assert warns , (
        "the generator dropped a list field it could not materialize without "
        f"saying so; warnings were {manifest['warnings']}"
    );
}


test "scalar-keyed dict fields still materialize their keys" {
    (txt, _m) = _gen(
        {"Source": ["inline_suppressions"], "UniScopeNode": ["names_in_scope"]}
    );
    int_keyed = _emit_fn(txt, "Source");
    assert "PyLong_FromLongLong(dk_" in int_keyed , (
        "Source.inline_suppressions is dict[int, set[str]] and must keep its "
        "int key conversion:\n"
        + int_keyed
    );
    str_keyed = _emit_fn(txt, "UniScopeNode");
    assert "_py_str(dk_" in str_keyed , (
        "UniScopeNode.names_in_scope is dict[str, Symbol] and must keep its "
        "str key conversion:\n"
        + str_keyed
    );
}


test "every emitted key conversion matches the declared key type" {
    (txt, _m) = _gen(_all_fields());
    blocks = _field_blocks(txt);
    assert blocks , "the sweep generated no fields; the layout shape drifted";
    bad: list[str] = [];
    for (ann, body) in blocks {
        for (needle, expected) in KEY_CTORS.items() {
            if needle in body {
                declared = _dict_key_type(ann);
                if declared != expected {
                    bad.append(
                        f"{ann!r}: key declared {declared!r} but converted "
                        f"with {needle.split('(')[0]} (valid only for "
                        f"{expected!r})"
                    );
                }
            }
        }
    }
    assert not bad , (
        f"{len(bad)} dict key conversion(s) disagree with their annotation:\n"
        + "\n".join(f"  {b}" for b in bad)
    );
}
