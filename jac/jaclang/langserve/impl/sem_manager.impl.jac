impl SemTokManager.postinit -> None {
    self.sem_tokens = self.gen_sem_tokens(self.ir);
    self.static_sem_tokens = self.gen_sem_tok_node(self.ir);
}

impl SemTokManager.collect_resolved_nodes(ir: uni.Module) -> list {
    import from pathlib { Path }

    target: (str | None) = None;
    if self.target_path {
        try {
            target = str(Path(self.target_path).resolve());
        } except Exception {
            target = self.target_path;
        }
    }
    resolved_cache: dict = {};
    def belongs(mp: (str | None)) -> bool {
        if target is None {
            return True;
        }
        if not mp {
            return False;
        }
        if mp not in resolved_cache {
            try {
                resolved_cache[mp] = str(Path(mp).resolve());
            } except Exception {
                resolved_cache[mp] = mp;
            }
        }
        return resolved_cache[mp] == target;
    }
    nodes: list = [];
    for nd in ir._in_mod_nodes {
        if isinstance(nd, uni.NameAtom) {
            if nd.sem_token and belongs(nd.loc.mod_path) {
                nodes.append(nd);
            }
        }
    }
    return nodes;
}

impl SemTokManager.gen_sem_tok_node(
    ir: uni.Module
) -> List[Tuple[(lspt.Position, int, int, uni.AstSymbolNode)]] {
    tokens: List[Tuple[(lspt.Position, int, int, uni.AstSymbolNode)]] = [];
    seen_locs: dict = {};
    try {
        for nd in self.collect_resolved_nodes(ir) {
            (line, col_start, col_end) = (
                (nd.loc.first_line - 1),
                (nd.loc.col_start - 1),
                (nd.loc.col_end - 1)
            );
            loc_key = (line, col_start);
            if loc_key not in seen_locs {
                seen_locs[loc_key] = True;
                length = col_end - col_start;
                pos = lspt.Position(line, col_start);
                tokens.append((pos, col_end, length, nd));
            }
        }
    } except Exception as e {
        logger.error(f"Error generating semantic token nodes: {e}");
    }
    tokens.sort(key=lambda (x: any) { (x[0].line, x[0].character); });
    return tokens;
}

impl SemTokManager.gen_sem_tokens(ir: uni.Module) -> list[int] {
    tokens = [];
    seen_locs: dict = {};
    try {
        for nd in self.collect_resolved_nodes(ir) {
            if nd.sem_token {
                (line, col_start, col_end) = (
                    (nd.loc.first_line - 1),
                    (nd.loc.col_start - 1),
                    (nd.loc.col_end - 1)
                );
                loc_key = (line, col_start);
                if loc_key not in seen_locs {
                    seen_locs[loc_key] = True;
                    length = col_end - col_start;
                    tokens.append(
                        (line, col_start, length, nd.sem_token[0], nd.sem_token[1])
                    );
                }
            }
        }
    } except Exception as e {
        logger.error(f"Error generating semantic tokens: {e}");
    }

    tokens.sort(key=lambda (x: any) { (x[0], x[1]); });
    result = [];
    (prev_line, prev_col) = (0, 0);
    for (line, col_start, length, tok_type, tok_mod) in tokens {
        result += [
            (line - prev_line),
            col_start if line != prev_line else (col_start - prev_col),
            length,
            tok_type,
            tok_mod
        ];
        (prev_line, prev_col) = (line, col_start);
    }
    return result;
}
