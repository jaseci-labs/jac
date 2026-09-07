import from jaclang.compiler.endpoint_contract { endpoint_descriptor, endpoint_key }

def boundary_audit(program: any) -> dict {
    boundaries: dict = {};
    effects: dict = {};
    for hub in program._search_hubs() {
        for module in hub.values() {
            if module is None or module.gen is None { continue; }
            manifest = module.gen.interop_manifest;
            effects.update(manifest.endpoint_effects);
            for binding in manifest.bindings.values() {
                source = binding.ast_node.find_parent_of_type(type(module))
                    if binding.ast_node is not None else None;
                if source is None { source = module; }
                identity = endpoint_key(source, binding.kind, binding.name);
                item = endpoint_descriptor(source, binding.kind, binding.name);
                item["placement"] = binding.source_context.value;
                item["callers"] = sorted([c.value for c in binding.callers]);
                item["parameters"] = dict(zip(binding.param_names, binding.param_types));
                item["result"] = binding.ret_type;
                item["unchecked"] = ["dynamic value shape"]
                    if "any" in binding.param_types or binding.ret_type == "any" else [];
                boundaries[identity] = item;
            }
        }
    }
    return {"version": 1, "boundaries": boundaries, "effects": effects};
}
