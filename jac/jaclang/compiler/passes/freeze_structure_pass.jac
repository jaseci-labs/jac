import from jaclang.compiler.passes.context { CompileContext }
import jaclang.compiler.frontend.unitree as uni;

walker FreezeStructurePass {
    has ctx: CompileContext,
        module: uni.Module;

    can freeze with uni.Module entry;
}

impl FreezeStructurePass.freeze with uni.Module entry {
    here.freeze_structure();
}
