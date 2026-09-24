import from jaclang.compiler.c_interop { foreign_struct_of_type }

impl NaIRGenPass._foreign_struct_name_of_type(t: any) -> (str | None) {
    arch = foreign_struct_of_type(t);
    if arch is None or arch.name is None {
        return None;
    }
    name = arch.name.value;
    return name if name in self.clib_struct_names else None;
}

impl NaIRGenPass._foreign_copy_box(src_ptr: ir.Value, name: str) -> ir.Value {
    stype = self.struct_types[name];
    if src_ptr.type != stype.as_pointer() {
        src_ptr = self.builder.bitcast(src_ptr, stype.as_pointer(), name="c.copy.src");
    }
    box = self._clib_alloc_box(name);
    self.builder.store(self.builder.load(src_ptr, name="c.copy.bytes"), box);
    self._mark_owned(box);
    return box;
}

impl NaIRGenPass._foreign_store_bytes(
    slot: ir.Value, value: ir.Value, sname: str
) -> None {
    stype = self.struct_types[sname];
    src = value;
    if src.type != stype.as_pointer() {
        src = self.builder.bitcast(src, stype.as_pointer(), name="c.store.src");
    }
    if slot.type != stype.as_pointer() {
        slot = self.builder.bitcast(slot, stype.as_pointer(), name="c.store.dst");
    }
    self.builder.store(self.builder.load(src, name="c.store.bytes"), slot);
    self._c_release_temp(value);
}

impl NaIRGenPass._c_release_temp(val: ir.Value) -> None {
    if not self._is_owned(val) or not isinstance(val.type, ir.PointerType) {
        return;
    }
    if self._nogc_headerless() {
        self._nogc_emit_drop(val, op="c_temp");
    } else {
        self._release_owned_args([val], op="c_temp");
    }
    val.is_owned = False;
}
