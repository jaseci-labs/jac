import from jaclang.compiler.frontend.unitree { Module }
import from jaclang.compiler.passes.context { CompileContext, CompilerPass }

import from jaclang.compiler.driver.program { JacProgram }

walker AppContextPass(CompilerPass) {
    has prog: JacProgram;
    static has HOST_PASS: bool = True;

    can run_walk with Module entry {
        self.prog.stamp_app_facts(here);
        self.prog.stamp_access_check_facts(here);
    }
}

walker AbsorbImportsPass(CompilerPass) {
    has prog: JacProgram;
    static has HOST_PASS: bool = True;

    can run_walk with Module entry {
        self.prog.resolve_absorb_imports(here);
    }
}

walker BoundaryFactsPass(CompilerPass) {
    has prog: JacProgram;
    static has HOST_PASS: bool = True;

    can run_walk with Module entry {
        self.prog.stamp_boundary_facts(here);
    }
}

walker NativeImportFactsPass(CompilerPass) {
    has prog: JacProgram;
    static has HOST_PASS: bool = True;

    can run_walk with Module entry {
        self.prog.stamp_native_import_facts(here);
    }
}
