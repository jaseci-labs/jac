impl mir_runtime_signature(name: str) -> tuple[list[MirType], MirType] {
    specs = MIR_RUNTIME_ABI.get(name);
    if specs is None {
        raise KeyError(f"no runtime function {name}");
    }
    return ([mir_runtime_spec(spec) for spec in specs[1:]], mir_runtime_spec(specs[0]));
}

impl mir_osp_signature(name: str) -> tuple[list[MirType], MirType] {
    specs = MIR_OSP_ABI.get(name);
    if specs is None {
        raise KeyError(f"no OSP function {name}");
    }
    return ([mir_runtime_spec(spec) for spec in specs[1:]], mir_runtime_spec(specs[0]));
}

impl mir_runtime_spec(spec: str) -> MirType {
    if spec == "int" {
        return mir_int();
    }
    if spec == "float" {
        return mir_float();
    }
    if spec == "none" {
        return mir_none();
    }
    if spec == "ptr" {
        return mir_c_ptr(mir_int(8, False));
    }
    if spec == "str.ref" {
        return mir_str_ref();
    }
    if spec == "ref" {
        return mir_ref();
    }
    if spec == "bool" {
        return mir_bool();
    }
    if spec == "i32" {
        return mir_int(32, True, True);
    }
    if spec == "any" {
        return mir_any();
    }
    if spec == "str" {
        return mir_str();
    }
    if spec == "list.int" {
        return mir_list(mir_int());
    }
    if spec == "opt.list.any" {
        return mir_opt(mir_list(mir_any()));
    }
    if spec == "fn.slot" {
        return mir_fn([mir_any(), mir_any()], mir_any());
    }
    if spec == "fn.pred" {
        return mir_fn([mir_int()], mir_bool());
    }
    raise KeyError(f"no runtime type spec {spec}");
}
