impl JcirGenPass.exit_match_stmt with MatchStmt exit {
    self.set_out(
        here,
        [
            self.nod(
                'Match',
                ['subject', 'cases'],
                [self.val(here.target), [self.val(x) for x in here.cases]]
            )
        ]
    );
}

impl JcirGenPass.exit_match_case with MatchCase exit {
    self.set_out(
        here,
        [
            self.nod(
                'match_case',
                ['pattern', 'guard', 'body'],
                [
                    self.val(here.pattern),
                    self.val(here.guard) if here.guard else None,
                    self.resolve_stmt_block(here.body)
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_match_or with MatchOr exit {
    self.set_out(
        here,
        [self.nod('MatchOr', ['patterns'], [[self.val(x) for x in here.patterns]])]
    );
}

impl JcirGenPass.exit_match_as with MatchAs exit {
    self.set_out(
        here,
        [
            self.nod(
                'MatchAs',
                ['name', 'pattern'],
                [here.name.sym_name, self.val(here.pattern) if here.pattern else None]
            )
        ]
    );
}

impl JcirGenPass.exit_match_wild with MatchWild exit {
    self.set_out(here, [self.nod('MatchAs', [], [])]);
}

impl JcirGenPass.exit_match_value with MatchValue exit {
    self.set_out(here, [self.nod('MatchValue', ['value'], [self.val(here.value)])]);
}

impl JcirGenPass.exit_match_singleton with MatchSingleton exit {
    self.set_out(here, [self.nod('MatchSingleton', ['value'], [here.value.lit_value])]);
}

impl JcirGenPass.exit_match_sequence with MatchSequence exit {
    self.set_out(
        here,
        [self.nod('MatchSequence', ['patterns'], [[self.val(x) for x in here.values]])]
    );
}

impl JcirGenPass.exit_match_mapping with MatchMapping exit {
    map_keys: list[CgNode] = [];
    map_patterns: list[CgNode] = [];
    rest: (str | None) = None;
    for i in here.values {
        if (
            isinstance(i, MatchKVPair)
            and isinstance(i.key, MatchValue)
            and self.outs(i.key.value)
            and self.outs(i.value)
        ) {
            map_keys.append(self.val(i.key.value));
            map_patterns.append(self.val(i.value));
        } elif isinstance(i, MatchStar) {
            rest = i.name.sym_name;
        }
    }
    self.set_out(
        here,
        [
            self.nod(
                'MatchMapping',
                ['keys', 'patterns', 'rest'],
                [map_keys, map_patterns, rest]
            )
        ]
    );
}

impl JcirGenPass.exit_match_k_v_pair with MatchKVPair exit {}

impl JcirGenPass.exit_match_star with MatchStar exit {
    self.set_out(here, [self.nod('MatchStar', ['name'], [here.name.sym_name])]);
}

impl JcirGenPass.exit_match_arch with MatchArch exit {
    self.set_out(
        here,
        [
            self.nod(
                'MatchClass',
                ['cls', 'patterns', 'kwd_attrs', 'kwd_patterns'],
                [
                    self.val(here.name),
                    [self.val(x) for x in (here.arg_patterns or [])],
                    [
                        x.key.sym_name
                        for x in (here.kw_patterns or [])
                        if isinstance(x.key, NameAtom)
                    ],
                    [self.val(x.value) for x in (here.kw_patterns or [])]
                ]
            )
        ]
    );
}
