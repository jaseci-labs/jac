import from jaclang.compiler.rust_bridge._blob {
    FnDesc,
    TAG_BOOL,
    TAG_FN,
    TAG_INT,
    TAG_UINT,
    TAG_F64,
    TAG_STR,
    TAG_BYTES,
    TAG_WIDE,
    TAG_VOID,
    tag_base,
    tag_is_opt,
    tag_is_ref,
    tag_ref_index,
    tag_is_shared,
    tag_is_borrowed,
    tag_is_map,
    tag_is_list,
    tag_map_value,
    tag_list_value
}

glob STATUS_OK = 0,
     STATUS_ERR = 1,
     STATUS_PANIC = 2,
     STATUS_CB_ERR = 3;


enum SlotKind {
    Str,
    Bytes,
    Bool,
    Int,
    Uint,
    F64,
    Void,
    OpaqueRef,
    Callback,
    Map,
    List,
    Wide,
    Unbridgeable
}


obj Slot {
    has kind: SlotKind,
        is_opt: bool = False,
        ref_index: int = -1,
        value: SlotKind | None = None,
        is_shared: bool = False,
        is_borrowed: bool = False,
        name: str = "";
}


def classify_scalar(tag: int) -> Slot {
    opt = tag_is_opt(tag);
    base = tag_base(tag);
    if base == TAG_STR {
        return Slot(kind=SlotKind.Str, is_opt=opt);
    }
    if base == TAG_BOOL {
        return Slot(kind=SlotKind.Bool, is_opt=opt);
    }
    if base == TAG_INT {
        return Slot(kind=SlotKind.Int, is_opt=opt);
    }
    if base == TAG_UINT {
        return Slot(kind=SlotKind.Uint, is_opt=opt);
    }
    if base == TAG_F64 {
        return Slot(kind=SlotKind.F64, is_opt=opt);
    }
    return Slot(kind=SlotKind.Unbridgeable, is_opt=opt);
}


def classify(tag: int) -> Slot {
    if tag == TAG_VOID {
        return Slot(kind=SlotKind.Void);
    }
    opt = tag_is_opt(tag);
    if tag_is_map(tag) {
        return Slot(
            kind=SlotKind.Map,
            is_opt=opt,
            value=classify_scalar(tag_map_value(tag)).kind
        );
    }
    if tag_is_list(tag) {
        return Slot(
            kind=SlotKind.List,
            is_opt=opt,
            value=classify_scalar(tag_list_value(tag)).kind
        );
    }
    if tag_is_ref(tag) {
        return Slot(
            kind=SlotKind.OpaqueRef,
            is_opt=opt,
            ref_index=tag_ref_index(tag),
            is_shared=tag_is_shared(tag),
            is_borrowed=tag_is_borrowed(tag)
        );
    }
    base = tag_base(tag);
    if base == TAG_STR {
        return Slot(kind=SlotKind.Str, is_opt=opt);
    }
    if base == TAG_BYTES {
        return Slot(kind=SlotKind.Bytes, is_opt=opt);
    }
    if base == TAG_WIDE {
        return Slot(kind=SlotKind.Wide, is_opt=opt);
    }
    if base == TAG_BOOL {
        return Slot(kind=SlotKind.Bool, is_opt=opt);
    }
    if base == TAG_INT {
        return Slot(kind=SlotKind.Int, is_opt=opt);
    }
    if base == TAG_UINT {
        return Slot(kind=SlotKind.Uint, is_opt=opt);
    }
    if base == TAG_F64 {
        return Slot(kind=SlotKind.F64, is_opt=opt);
    }
    if base == TAG_FN {
        return Slot(kind=SlotKind.Callback, is_opt=opt);
    }
    return Slot(kind=SlotKind.Unbridgeable, is_opt=opt);
}


def lower_signature(fd: FnDesc) -> list[Slot] {
    slots = [];
    for p in fd.params {
        s = classify(p.tag);
        s.name = p.name;
        slots.append(s);
    }
    slots.append(classify(fd.ret));
    return slots;
}
