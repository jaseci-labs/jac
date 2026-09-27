import from jaclang.compiler.passes.context { CompileContext, CompilerPass }
import jaclang.compiler.frontend.unitree as uni;

walker FreezeStructurePass(CompilerPass) {
    can freeze with uni.Module entry;
}

impl FreezeStructurePass.freeze with uni.Module entry {
    here.freeze_structure();
}
