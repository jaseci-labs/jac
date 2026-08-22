# Phase 3 flowgraph verification tests (INTEGRATION_PLAN.md).
#
# Hand-built CFG fixtures for calculate_stackdepth / verify_cfg diagnostics.

import from objects { PyInt }
import from opcode_meta {
    OP_LOAD_CONST,
    OP_POP_TOP,
    OP_RETURN_VALUE,
    OP_POP_JUMP_IF_FALSE,
    OP_BINARY_OP,
    NB_ADD,
}
import from compiler_ir { unverified_cfg, basicblock, mk_instr, mk_jump, loc, }
import from flowgraph { verify_cfg }
import from compiler_diagnostics { compiler_diag_kind, compiler_diag_message }

def mk_unit(blocks: list[basicblock]) -> unverified_cfg {
    u = unverified_cfg(
        filename="<fg>", name="<module>", qualname="<module>", firstlineno=1
    );
    u.blocks = blocks;
    u.next_block_id = len(blocks);
    u.add_const(PyInt(t="int", val=1));
    return u;
}

def one_block(opcode: int, oparg: int = 0) -> unverified_cfg {
    b = basicblock(id=0, instrs=[mk_instr(opcode, oparg, loc(1, 1, 0, 1))]);
    return mk_unit([b]);
}

test "flowgraph: immediate stack underflow rejected" {
    cfg = verify_cfg(one_block(OP_POP_TOP));
    assert cfg.diag is not None;
    assert compiler_diag_kind(cfg.diag) == "ValueError";
    assert "underflow" in compiler_diag_message(cfg.diag);
}

test "flowgraph: branch-only underflow rejected" {
    load = mk_instr(OP_LOAD_CONST, 0, loc(1, 1, 0, 1));
    pop = mk_instr(OP_POP_TOP, 0, loc(1, 1, 0, 1));
    b0 = basicblock(id=0, instrs=[load]);
    b0.instrs.append(mk_jump(OP_POP_JUMP_IF_FALSE, 1, loc(1, 1, 0, 1)));
    b1 = basicblock(id=1, instrs=[pop]);
    cfg = verify_cfg(mk_unit([b0, b1]));
    assert cfg.diag is not None;
    assert compiler_diag_kind(cfg.diag) == "ValueError";
}

test "flowgraph: inconsistent join depth rejected" {
    load = mk_instr(OP_LOAD_CONST, 0, loc(1, 1, 0, 1));
    b0 = basicblock(id=0, instrs=[load]);
    b0.instrs.append(mk_jump(OP_POP_JUMP_IF_FALSE, 2, loc(1, 1, 0, 1)));
    b1 = basicblock(id=1, instrs=[load]);
    b2 = basicblock(id=2, instrs=[mk_instr(OP_RETURN_VALUE, 0, loc(1, 1, 0, 1))]);
    cfg = verify_cfg(mk_unit([b0, b1, b2]));
    assert cfg.diag is not None;
    assert compiler_diag_kind(cfg.diag) == "ValueError";
    assert "inconsistent" in compiler_diag_message(cfg.diag);
}

test "flowgraph: invalid jump target rejected" {
    load = mk_instr(OP_LOAD_CONST, 0, loc(1, 1, 0, 1));
    b0 = basicblock(
        id=0, instrs=[load, mk_jump(OP_POP_JUMP_IF_FALSE, 99, loc(1, 1, 0, 1))]
    );
    b1 = basicblock(id=1, instrs=[mk_instr(OP_RETURN_VALUE, 0, loc(1, 1, 0, 1))]);
    cfg = verify_cfg(mk_unit([b0, b1]));
    assert cfg.diag is not None;
    assert compiler_diag_kind(cfg.diag) == "ValueError";
    assert "jump target" in compiler_diag_message(cfg.diag);
}

test "flowgraph: unknown opcode stack metadata rejected" {
    b0 = basicblock(id=0, instrs=[mk_instr(9999, 0, loc(1, 1, 0, 1))]);
    cfg = verify_cfg(mk_unit([b0]));
    assert cfg.diag is not None;
    assert compiler_diag_kind(cfg.diag) == "SystemError";
    assert "stack effect" in compiler_diag_message(cfg.diag);
}

test "flowgraph: instructions after terminator rejected" {
    b0 = basicblock(
        id=0,
        instrs=[
            mk_instr(OP_LOAD_CONST, 0, loc(1, 1, 0, 1)),
            mk_instr(OP_RETURN_VALUE, 0, loc(1, 1, 0, 1)),
            mk_instr(OP_POP_TOP, 0, loc(1, 1, 0, 1)),

        ]
    );
    cfg = verify_cfg(mk_unit([b0]));
    assert cfg.diag is not None;
    assert compiler_diag_kind(cfg.diag) == "ValueError";
    assert "after terminator" in compiler_diag_message(cfg.diag);
}

test "flowgraph: valid straight-line stacksize" {
    b0 = basicblock(
        id=0,
        instrs=[
            mk_instr(OP_LOAD_CONST, 0, loc(1, 1, 0, 1)),
            mk_instr(OP_LOAD_CONST, 0, loc(1, 1, 0, 1)),
            mk_instr(OP_BINARY_OP, NB_ADD, loc(1, 1, 0, 1)),
            mk_instr(OP_RETURN_VALUE, 0, loc(1, 1, 0, 1)),

        ]
    );
    cfg = verify_cfg(mk_unit([b0]));
    assert cfg.diag is None;
    assert cfg.stacksize == 2;
}
