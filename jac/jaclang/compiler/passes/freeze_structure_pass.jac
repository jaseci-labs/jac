walker FreezeStructurePass(CompilerPass) {
    static has contract: PassContract = PassContract(provides=(AnalysisFact.FROZEN, ));

    can freeze with uni.Module entry;
}
