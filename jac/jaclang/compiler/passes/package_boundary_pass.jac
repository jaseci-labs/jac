import from jaclang.compiler.passes.context { CompileContext }
import from jaclang.compiler.frontend.unitree { Import, Module, ModulePath }

walker PackageBoundaryPass {
    has ctx: CompileContext,
        module: Module;

    can run_walk with Module entry;
    def _targets(imp: Import) -> list[ModulePath];
    def _check_target(importer_root: (str | None), path_node: ModulePath) -> None;
}
