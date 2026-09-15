impl SemTokManager.postinit -> None {
    self.static_sem_tokens = self.gen_sem_tok_node(self.ir);
    self.sem_tokens = self.encode_tokens();
    for nd in self.ir._in_mod_nodes {
        if isinstance(nd, uni.Token)
            and (self.target_path is None or nd.loc.mod_path == self.target_path) {
            self.tokens_by_line.setdefault(nd.loc.first_line - 1, []).append(nd);
        }
    }
}

impl SemTokManager.collect_resolved_nodes(ir: uni.Module) -> list[uni.NameAtom] {
    import from pathlib { Path }

    target: (str | None) = None;
    if self.target_path {
        try {
            target = str(Path(self.target_path).resolve());
        } except Exception {
            target = self.target_path;
        }
    }
    resolved_cache: dict[str, str] = {};
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
    nodes: list[uni.NameAtom] = [];
    for nd in ir._in_mod_nodes {
        if isinstance(nd, uni.NameAtom) {
            if nd.sem_token and belongs(nd.loc.mod_path) {
                nodes.append(nd);
            }
        }
    }
    return nodes;
}

impl SemTokManager.gen_sem_tok_node(ir: uni.Module) -> list[SemanticToken] {
    tokens: list[SemanticToken] = [];
    seen_locs: dict[tuple[int, int], bool] = {};
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
                tokens.append(SemanticToken(pos, col_end, length, nd));
            }
        }
    } except Exception as e {
        logger.error(f"Error generating semantic token nodes: {e}");
    }
    tokens.sort(
        key=lambda (token: SemanticToken) { (
            token.position.line,
            token.position.character
        ); }
    );
    return tokens;
}

impl SemTokManager.encode_tokens -> list[int] {
    result: list[int] = [];
    (prev_line, prev_col) = (0, 0);
    for token in self.static_sem_tokens {
        (position, length, nd) = (token.position, token.length, token.symbol);
        if nd.sem_token is None {
            continue;
        }
        (line, col) = (position.line, position.character);
        result.extend(
            [
                line - prev_line,
                col if line != prev_line else col - prev_col,
                length,
                nd.sem_token[0],
                nd.sem_token[1]
            ]
        );
        (prev_line, prev_col) = (line, col);
    }
    return result;
}
