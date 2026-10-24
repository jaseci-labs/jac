def _replay_diags(
    diags: list[SrcDiag], from_pass: type, prog: JacProgram, diag_src: Source
);

def parse_diags(
    source: str, file_path: str = "<input>"
) -> tuple[bool, list[SrcDiag], list[SrcDiag]];

def parse(
    source: str, file_path: str = "<input>", prog: (JacProgram | None) = None
) -> tuple[Module, bool];

def parse_expression(
    source: str, file_path: str = "<input>", prog: JacProgram | None = None
) -> tuple[Expr, bool];

def finish_parse(
    module: Module,
    p_errs: int,
    p_diags: list[SrcDiag],
    comments: list[CommentData],
    lex_diags: list[SrcDiag],
    lex_errs: int,
    prog: (JacProgram | None)
) -> bool;

def ignore_directive(text: str) -> (str | None);

def parse_woven(
    source_str: str,
    file_path: str,
    prog: (JacProgram | None),
    annexes: list[WovenAnnex],
    early_context: str = "",
    load_kernel: bool = True
) -> tuple[Module, bool];

def annex_paths(file_path: str) -> list[str];

def annex_sources(file_path: str) -> list[WovenAnnex];
