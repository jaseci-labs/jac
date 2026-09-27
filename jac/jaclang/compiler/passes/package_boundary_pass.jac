import from jaclang.compiler.passes.context { CompilerPass }
import from jaclang.compiler.frontend.unitree { Import, Module, ModulePath }
import from jaclang.compiler.frontend.host { ProjectFacts }

walker PackageBoundaryPass(CompilerPass) {
    can run_walk with Module entry;
    def _targets(imp: Import) -> list[ModulePath];
    def _package_of(path: str) -> (ProjectFacts | None);
    def _check_target(importer: (ProjectFacts | None), path_node: ModulePath) -> None;
}

def export_matches(module: str, pattern: str) -> bool;
