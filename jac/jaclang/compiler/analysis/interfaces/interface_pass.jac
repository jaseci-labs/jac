import os;
import from jaclang.compiler.pipeline.program_pass { ProgramTransform }
import jaclang.compiler.ir.schema as uni;

walker InterfaceFactsPass(ProgramTransform) {
    def transform(ir_in: uni.Module) -> uni.Module {
        import from jaclang.compiler.pipeline.contracts { ProductUnavailable }
        import from jaclang.compiler.analysis.interfaces.catalog_builder {
            CatalogBuilder
        }
        import from jaclang.compiler.analysis.interfaces.facts {
            IncoherentInterface,
            InterfaceProduct
        }
        import from jaclang.compiler.session.cache.interface_codec {
            encode_interface,
            read_iface_hash
        }
        import from jaclang.compiler.pipeline.keys { INTERFACE }
        path = os.path.realpath(ir_in.loc.mod_path);
        registry = self.prog.iface_registry();
        if not registry.interface_cacheable(path, ir_in) {
            raise ProductUnavailable('Module has no cacheable interface');
        }

        dependencies = set(registry.direct_deps.get(path, {}));
        dependencies.update(
            edge.target
            for edge in self.prog.deps.imports.get(path, [])
            if edge.jac and edge.target != path
        );
        was_building = path in registry.building;
        registry.building.add(path);
        try {
            for dependency in sorted(dependencies) {
                dependency_entry = registry.ensure(dependency);
                if dependency_entry is not None {
                    registry.direct_deps.setdefault(path, {})[dependency] = dependency_entry.digest;
                }
            }
        } finally {
            if not was_building {
                registry.building.discard(path);
            }
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
            raise ProductUnavailable(
                f'Interface has unresolved class scopes: {writer.orphans}'
            );
        }
        encoded = encode_interface(prepared);
        self.prog.analysis.publish(
            path, INTERFACE, InterfaceProduct(encoded, read_iface_hash(encoded) or '')
        );
        registry.publish_interface(path, encoded);
        return ir_in;
    }
}
