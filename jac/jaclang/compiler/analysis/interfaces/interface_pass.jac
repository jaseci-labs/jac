import os;
import from jaclang.compiler.pipeline.program_pass { ProgramTransform }
import jaclang.compiler.ir.schema as uni;

walker InterfaceFactsPass(ProgramTransform) {
    def transform(ir_in: uni.Module) -> uni.Module {
        import from jaclang.compiler.analysis.interfaces.catalog_builder {
            CatalogBuilder
        }
        import from jaclang.compiler.analysis.interfaces.facts { InterfaceProduct }
        import from jaclang.compiler.session.cache.artifact_codec {
            is_compiler_tree_path,
            is_stub_like_path
        }
        import from jaclang.compiler.session.cache.interface_codec {
            encode_interface,
            read_iface_hash
        }
        import from jaclang.compiler.pipeline.keys { INTERFACE }
        path = os.path.realpath(ir_in.loc.mod_path);
        registry = self.prog.iface_registry();
        if not registry.interface_cacheable(path, ir_in) {
            self.prog.analysis.publish(
                path,
                INTERFACE,
                InterfaceProduct(None, '', 'Module has no cacheable interface')
            );
            return ir_in;
        }

        cached = registry.cached_interface(path);
        if cached is not None {
            self.prog.analysis.publish(
                path, INTERFACE, InterfaceProduct(cached, read_iface_hash(cached) or '')
            );
            return ir_in;
        }
        writer = CatalogBuilder(
            evaluator=self.prog.get_type_evaluator(),
            pkg_dir=registry.package_directory(),
            boundary=ir_in
        );
        writer.add_module(ir_in, ir_in.name or '');
        writer.force_all();
        prepared = writer.prepare(path, {});
        if writer.orphans {
            registry.reject_interface(path);
            self.prog.analysis.publish(
                path,
                INTERFACE,
                InterfaceProduct(
                    None, '', f'Interface has unresolved class scopes: {writer.orphans}'
                )
            );
            return ir_in;
        }
        dependencies = set(registry.direct_deps.get(path, {}));
        dependencies.update(
            os.path.realpath(module.loc.mod_path)
            for module in writer.modules
            if not writer.in_boundary(module)
                and module.loc.mod_path
                and not is_stub_like_path(module.loc.mod_path)
                and not is_compiler_tree_path(module.loc.mod_path)
        );
        dependencies.discard(path);
        was_building = path in registry.building;
        registry.building.add(path);
        try {
            for dependency in sorted(dependencies) {
                dependency_entry = registry.ensure(dependency);
                registry.direct_deps.setdefault(path, {})[dependency] = dependency_entry.digest
                    if dependency_entry is not None
                    else '';
            }
        } finally {
            if not was_building {
                registry.building.discard(path);
            }
        }
        encoded = encode_interface(prepared);
        self.prog.analysis.publish(
            path, INTERFACE, InterfaceProduct(encoded, read_iface_hash(encoded) or '')
        );
        registry.publish_interface(path, encoded);
        return ir_in;
    }
}
