def declaration_body_roots(module: Module) -> set[int];

def importer_lowers_bodies(module: Module) -> bool;

walker DeclarationTypePass(TypeCheckPass) {
    static has contract: PassContract = PassContract(
        provides=(AnalysisFact.DECL_TYPES, )
    );

    has _bodies: set[int] = set();

    can prepare with entry;
    can finish with exit;
    can enter_walk with UniNode entry;
    can exit_walk with UniNode exit;
    override def _body_always_returns(body: list[CodeBlockStmt]) -> bool;
    override def _stamp_fixed_width -> None;
}
