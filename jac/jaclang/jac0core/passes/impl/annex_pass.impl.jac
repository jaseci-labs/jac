impl JacAnnexPass.transform(self: JacAnnexPass, ir_in: Module) -> Module {
    for annex_mod in ir_in.annex_mods {
        JacAnnexPass._merge_annex(ir_in, annex_mod);
    }
    ir_in.annex_mods = [];
    return ir_in;
}

impl JacAnnexPass._merge_annex(nd: Module, annex_mod: Module) -> None {
    merge_annex_into(nd, annex_mod);
}
