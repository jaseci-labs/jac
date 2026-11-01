"""The runtime functions generated code calls, by symbol, with their MIR
signatures: the return spec first, then the parameters. The runtime units in
jaclang/runtime/native define them in Jac. A `str.ref` result is an owned
string the caller releases."""
glob MIR_RUNTIME_ABI: dict[str, list[str]] = {
         "__jac_rt_str_cmp": ["int", "ptr", "int", "ptr", "int"],
         "__jac_rt_str_len": ["int", "ptr", "ptr", "int"],
         "__jac_rt_str_new": ["str.ref", "ptr", "int"],
         "__jac_rt_str_concat": ["str.ref", "ptr", "int", "ptr", "int"],
         "__jac_rt_str_from_int": ["str.ref", "int"],
         "__jac_rt_str_size": ["int", "str.ref"],
         "__jac_rt_write": ["none", "int", "ptr", "int"],
         "__jac_rt_write_int": ["none", "int", "int"]
     };

def mir_runtime_signature(name: str) -> tuple[list[MirType], MirType];

def mir_runtime_spec(spec: str) -> MirType;
