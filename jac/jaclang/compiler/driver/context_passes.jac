import from jaclang.compiler.passes.transform { Transform }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.unitree { Module }

walker AppContextPass(Transform) {
    has prog: JacProgram;
    static has HOST_PASS: bool = True;

    def transform(ir_in: Module) -> Module {
        self.prog._get_compiler().stamp_app_facts(ir_in, self.prog);
        self.prog._get_compiler().stamp_access_check_facts(ir_in);
        return ir_in;
    }
}

walker AbsorbImportsPass(Transform) {
    has prog: JacProgram;
    static has HOST_PASS: bool = True;

    def transform(ir_in: Module) -> Module {
        self.prog._get_compiler().resolve_absorb_imports(ir_in, self.prog);
        return ir_in;
    }
}

walker BoundaryFactsPass(Transform) {
    has prog: JacProgram;
    static has HOST_PASS: bool = True;

    def transform(ir_in: Module) -> Module {
        self.prog._get_compiler().stamp_boundary_facts(ir_in, self.prog);
        return ir_in;
    }
}

walker NativeImportFactsPass(Transform) {
    has prog: JacProgram;
    static has HOST_PASS: bool = True;

    def transform(ir_in: Module) -> Module {
        self.prog._get_compiler().stamp_native_import_facts(ir_in, self.prog);
        return ir_in;
    }
}
