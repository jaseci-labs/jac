walker FreezeStructurePass(CompilerPass) {
    can freeze with uni.Module entry;
}

impl FreezeStructurePass.freeze with uni.Module entry {
    here.freeze_structure();
}
