def _is_comptime_marker(nd: UniNode) -> bool;

def comptime_reach(top: UniNode) -> set[int];

walker ComptimeResolvePass(TypeCheckPass) {
    static has contract: PassContract = PassContract(
        provides=(AnalysisFact.COMPTIME, )
    );

    has _armed: bool = False,
        _keep: set[int] = set();

    can prepare with entry;
    can finish with exit;
    can enter_walk with UniNode entry;
    can exit_walk with UniNode exit;
}
