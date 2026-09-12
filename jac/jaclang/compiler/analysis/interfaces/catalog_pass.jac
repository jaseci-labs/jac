import sys;
import from jaclang.compiler.pipeline.program_pass { QueryTransform }
import from jaclang.compiler.ir.schema { Module }
import from jaclang.compiler.analysis.interfaces.facts {
    CatalogRequest,
    CatalogProduct
}
import from jaclang.compiler.analysis.interfaces.catalog_builder { CatalogBuilder }

walker CatalogPreparePass(QueryTransform[CatalogProduct]) {
    has request: CatalogRequest;

    def transform(ir_in: Module) -> Module {
        evaluator = self.prog.get_type_evaluator();
        writer = CatalogBuilder(
            evaluator=evaluator, pkg_dir=self.request.package_directory
        );
        prelude: list[tuple[str, Module | None]] = [
            ("builtins", evaluator.builtins_module),
            ("typing", evaluator.typing_module),
            ("types", evaluator.types_module),
            ("enum", evaluator.enum_module),
            ("jac_builtins", evaluator.jac_builtins_module),
            ("dom_types", evaluator.dom_types_module),
            ("na_builtins", evaluator.na_builtins_module),
            ("js_globals", evaluator.js_globals_module)
        ];
        for (name, module) in prelude {
            if module is not None {
                writer.add_module(module, name);
            }
        }
        failures: list[str] = [];
        for (index, (name, path)) in enumerate(self.request.files) {
            if self.is_canceled() {
                return ir_in;
            }
            if not self.request.quiet and index % 25 == 0 {
                sys.stderr.write(f"stubcat: loading {name} ({index} done)\n");
                sys.stderr.flush();
            }
            try {
                module = self.prog.load_dependency_module(path);
            } except Exception as error {
                failures.append(f"{name}: {type(error).__name__}: {error}");
                continue;
            }
            writer.add_module(module, name);
        }
        writer.force_all();
        prepared = writer.prepare(
            self.request.key, evaluator.ambient_typing_names_by_module
        );
        self.result = CatalogProduct(prepared, writer.statistics(), failures);
        return ir_in;
    }
}
