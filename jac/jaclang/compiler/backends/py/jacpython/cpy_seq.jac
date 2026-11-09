# Instruction sequences shared by codegen and the flowgraph: a port of
# CPython's Python/instruction_sequence.c and the code unit metadata of
# Include/internal/pycore_compile.h.

obj srcloc {
    has lineno: int,
        end_lineno: int,
        col_offset: int,
        end_col_offset: int;
}

def mkloc(
    lineno: int, end_lineno: int, col_offset: int, end_col_offset: int
) -> srcloc {
    return srcloc(
        lineno=lineno,
        end_lineno=end_lineno,
        col_offset=col_offset,
        end_col_offset=end_col_offset
    );
}

def no_location -> srcloc {
    return mkloc(-1, -1, -1, -1);
}

def next_location -> srcloc {
    return mkloc(-2, -2, -2, -2);
}

def same_location(a: srcloc, b: srcloc) -> bool {
    return a.lineno == b.lineno
        and a.end_lineno == b.end_lineno
        and a.col_offset == b.col_offset
        and a.end_col_offset == b.end_col_offset;
}

obj seq_instr {
    has opcode: int,
        oparg: int,
        loc: srcloc,
        h_label: int = -1,
        h_startdepth: int = -1,
        h_preserve_lasti: int = 0,
        target: int = 0,
        offset: int = 0;
}

obj instr_seq {
    has instrs: list[seq_instr] = [],
        next_free_label: int = 0,
        labelmap: list[int] = [],
        labels_applied: bool = False,
        nested: list[instr_seq] = [],
        annotations_code: instr_seq | None = None;

    def new_label -> int {
        self.next_free_label += 1;
        return self.next_free_label;
    }

    def use_label(lbl: int) {
        while len(self.labelmap) <= lbl {
            self.labelmap.append(-111);
        }
        self.labelmap[lbl] = len(self.instrs);
    }

    def addop(opcode: int, oparg: int, lc: srcloc) {
        self.instrs.append(seq_instr(opcode=opcode, oparg=oparg, loc=lc));
    }

    def insert_instruction(pos: int, opcode: int, oparg: int, lc: srcloc) {
        self.instrs.insert(pos, seq_instr(opcode=opcode, oparg=oparg, loc=lc));
        index = 0;
        while index < len(self.labelmap) {
            if self.labelmap[index] >= pos {
                self.labelmap[index] += 1;
            }
            index += 1;
        }
    }

    def apply_label_map {
        if self.labels_applied {
            return;
        }
        for instr in self.instrs {
            if has_target(instr.opcode) {
                instr.oparg = self.labelmap[instr.oparg];
            }
            if instr.h_label >= 0 {
                instr.h_label = self.labelmap[instr.h_label];
            }
        }
        self.labelmap = [];
        self.labels_applied = True;
    }

    def set_annotations_code(annotations: instr_seq) {
        self.annotations_code = annotations;
    }

    def add_nested(nested: instr_seq) {
        self.nested.append(nested);
    }
}

# _PyCompile_CodeUnitMetadata. CPython keeps consts, names and the variable
# kinds in dicts mapping each key to its index; the lists hold the keys in
# index order and the dicts the index of each key.
obj code_unit_metadata {
    has name: str = "",
        qualname: str = "",
        consts: list[PyObj] = [],
        const_index: dict[str, int] = {},
        names: list[str] = [],
        name_index: dict[str, int] = {},
        varnames: list[str] = [],
        varname_index: dict[str, int] = {},
        cellvars: list[str] = [],
        cellvar_index: dict[str, int] = {},
        freevars: list[str] = [],
        freevar_index: dict[str, int] = {},
        fasthidden: dict[str, bool] = {},
        argcount: int = 0,
        posonlyargcount: int = 0,
        kwonlyargcount: int = 0,
        firstlineno: int = 0;
}
