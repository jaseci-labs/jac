class SemTokManager {
    """Initialize semantic token manager."""
    def init(self: SemTokManager, ir: uni.Module) -> None {
        self.sem_tokens: List[int] = self.gen_sem_tokens(ir);
        self.aaaaastatic_sem_tokens:
            List[Tuple[lspt.Position, int, int, uni.AstSymbolNode]] =
            self.gen_sem_tok_node(ir);
    }
}


def init(
    self: ModuleManager,
    program: JacProgram,
    sem_managers: <>dict,
    program2: JacProgram,
    sem_managers2: <>dict
) -> None { }
