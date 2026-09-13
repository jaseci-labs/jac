import type from jaclang.compiler.backends.common.artifacts { InteropManifest }

def interop_record(manifest: InteropManifest | None) -> dict {
    if manifest is None {
        return {};
    }
    interop_data: dict = {'bindings': {}};
    for (name, binding) in manifest.bindings.items() {
        interop_data['bindings'][name] = {
            'name': binding.name,
            'source_context': binding.source_context.value,
            'callers': [c.value for c in binding.callers],
            'ret_type': binding.ret_type,
            'param_types': binding.param_types,
            'param_names': binding.param_names,
            'source_module': binding.source_module,
            'kind': binding.kind,
            'provider_app': binding.provider_app,
            'native_contract': binding.native_contract,
            'endpoint_id': binding.endpoint_id
        };
    }

    interop_data['func_access'] = dict(manifest.func_access);
    interop_data['walker_access'] = dict(manifest.walker_access);
    interop_data['endpoint_effects'] = dict(manifest.endpoint_effects);
    interop_data['native_host_imports'] = dict(manifest.native_host_imports);
    interop_data['app_edges'] = list(manifest.app_edges);
    interop_data['provider_routes'] = dict(manifest.provider_routes);
    return interop_data;
}


def decode_interop_record(cached_interop: dict[str, any]) -> InteropManifest {
    import from jaclang.compiler.backends.common.artifacts {
        InteropManifest,
        InteropBinding,
        InteropContext
    }
    manifest = InteropManifest();
    cached_bindings: dict[str, dict[str, any]] = cached_interop.get('bindings', {});
    for (name, data) in cached_bindings.items() {
        binding = InteropBinding(
            name=data['name'],
            source_context=InteropContext(data['source_context']),
            callers={InteropContext(c) for c in data.get('callers', [])},
            ret_type=data.get('ret_type', 'int'),
            param_types=data.get('param_types', []),
            param_names=data.get('param_names', []),
            source_module=data.get('source_module'),
            kind=data.get('kind', 'function'),
            provider_app=data['provider_app'],
            native_contract=data['native_contract'],
            endpoint_id=data['endpoint_id']
        );
        manifest.bindings[name] = binding;
    }
    manifest.func_access.update(cached_interop.get('func_access', {}));
    manifest.walker_access.update(cached_interop.get('walker_access', {}));
    manifest.endpoint_effects.update(cached_interop.get('endpoint_effects', {}));
    manifest.native_host_imports.update(cached_interop['native_host_imports']);
    manifest.app_edges.extend(cached_interop['app_edges']);
    manifest.provider_routes.update(cached_interop['provider_routes']);
    return manifest;
}
