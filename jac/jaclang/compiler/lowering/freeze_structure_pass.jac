import jaclang.compiler.ir.schema as uni;
import from jaclang.compiler.pipeline.pass_base { Transform }

walker FreezeStructurePass(Transform) {
    def transform(ir_in: uni.Module) -> uni.Module;
    can run_walk with uni.Module entry;
}

impl FreezeStructurePass.transform(ir_in: uni.Module) -> uni.Module {
    self.ir_out = ir_in;
    ir_in spawn self;
    return ir_in;
}

impl FreezeStructurePass.run_walk with uni.Module entry {
    here.freeze_structure();
}
