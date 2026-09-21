import from jaclang.compiler.frontend.unitree { Module }
import from jaclang.compiler.passes.context { CompileContext }

import from jaclang.compiler.driver.program { JacProgram }

walker AppContextPass {
    has ctx: CompileContext,
        module: Module,
        prog: JacProgram;

    static has HOST_PASS: bool = True;

    can run_walk with Module entry {
        self.prog._get_compiler().stamp_app_facts(here, self.prog);
        self.prog._get_compiler().stamp_access_check_facts(here);
    }
}

walker AbsorbImportsPass {
    has ctx: CompileContext,
        module: Module,
        prog: JacProgram;

    static has HOST_PASS: bool = True;

    can run_walk with Module entry {
        self.prog._get_compiler().resolve_absorb_imports(here, self.prog);
    }
}

walker BoundaryFactsPass {
    has ctx: CompileContext,
        module: Module,
        prog: JacProgram;

    static has HOST_PASS: bool = True;

    can run_walk with Module entry {
        self.prog._get_compiler().stamp_boundary_facts(here, self.prog);
    }
}

walker NativeImportFactsPass {
    has ctx: CompileContext,
        module: Module,
        prog: JacProgram;

    static has HOST_PASS: bool = True;

    can run_walk with Module entry {
        self.prog._get_compiler().stamp_native_import_facts(here, self.prog);
    }
}
