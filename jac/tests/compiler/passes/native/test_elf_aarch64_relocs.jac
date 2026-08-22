"""aarch64's PC-relative relocations, as the in-house ELF linker applies them.

The linker refuses -- loudly, and correctly -- any relocation it has no handler
for, rather than emitting a binary with an unrelocated reference. That refusal
is only as good as the handler table behind it, and the table was missing the
whole conditional-branch family: `B.cond`, `CBZ`/`CBNZ` and `LDR`-literal
(`R_AARCH64_CONDBR19`, `R_AARCH64_LD_PREL_LO19`), `TBZ`/`TBNZ`
(`R_AARCH64_TSTBR14`), and the non-page `ADR` form (`R_AARCH64_ADR_PREL_LO21`).

Hand-written assembly reaches for those constantly while the compiler's own
output mostly does not, so the gap stayed invisible until a sealed root's
closure grew far enough to pull the poly1305 core out of the bundled libcrypto.
Then the linux-aarch64 release leg refused every build with

    ELF shared linker: no handler for relocation type 280
    (symbol 'poly1305_emit', section '.text', e_machine 183)

The relocation numbers below are restated from the ELF-for-aarch64 ABI rather
than imported from the linker: a test that reads its expectations out of the
code under test cannot catch a wrong constant. The expected words are likewise
written out in full, so a mask that clears a bit it should have kept fails here
instead of in a binary that jumps to the wrong address.
"""

import struct;
import from jaclang.compiler.passes.native.elf_linker { ArchConfig }

glob EM_AARCH64: int = 183;

# ELF for the ARM 64-bit Architecture, section "Relocation codes".
glob R_LD_PREL_LO19: int = 273,
     R_ADR_PREL_LO21: int = 274,
     R_ADR_PREL_PG_HI21: int = 275,
     R_ADR_PREL_PG_HI21_NC: int = 276,
     R_TSTBR14: int = 279,
     R_CONDBR19: int = 280;

"""Apply one relocation to a lone instruction word; None means the linker refused it."""
def _patch(
    rtype: int, insn: int, sym_addr: int, addend: int, patch_vaddr: int
) -> (int | None) {
    arch = ArchConfig.from_e_machine(EM_AARCH64);
    if arch is None {
        raise AssertionError("aarch64 must have an ArchConfig to relocate against");
    }
    buf = bytearray(struct.pack("<I", insn));
    if not arch.apply_reloc(rtype, buf, 0, sym_addr, addend, patch_vaddr) {
        return None;
    }
    return struct.unpack_from("<I", buf, 0)[0];
}

test "a conditional branch's displacement lands in imm19, forwards and back" {
    # `b.ne` (0x54000001) to a target 0x80 bytes ahead: imm19 = 0x80 >> 2 = 0x20,
    # which sits at bits 23:5, so 0x20 << 5 = 0x400.
    fwd = _patch(R_CONDBR19, 0x54000001, 0x1080, 0, 0x1000);
    assert fwd == 0x54000401 , (
        f"a forward conditional branch encoded as {fwd}, want 0x54000401"
    );

    # The same branch 0x80 bytes backwards: -0x20 in 19-bit two's complement is
    # 0x7FFE0. An unsigned shift here would silently encode a forward jump.
    back = _patch(R_CONDBR19, 0x54000001, 0x0F80, 0, 0x1000);
    assert back == 0x54FFFC01 , (
        f"a backward conditional branch encoded as {back}, want 0x54FFFC01"
    );

    # Every bit outside imm19 must survive the patch -- condition code included.
    masked = _patch(R_CONDBR19, 0xFFFFFFFF, 0x1080, 0, 0x1000);
    assert masked == 0xFF00041F , (
        f"imm19's mask disturbed bits outside the field: {masked}, want 0xFF00041F"
    );
}

test "an LDR-literal shares imm19 with the conditional branches" {
    # `ldr x0, <literal>` (0x58000000) reading a word 0x80 bytes ahead.
    got = _patch(R_LD_PREL_LO19, 0x58000000, 0x1080, 0, 0x1000);
    assert got == 0x58000400 , (f"an LDR-literal encoded as {got}, want 0x58000400");
}

test "TBZ/TBNZ's displacement lands in the narrower imm14" {
    # imm14 is bits 18:5 -- five bits narrower than imm19, so a handler that
    # reused imm19's mask would clear the bit-position field above it.
    got = _patch(R_TSTBR14, 0x36080000, 0x2040, 0, 0x2000);
    assert got == 0x36080200 , f"a test-and-branch encoded as {got}, want 0x36080200";

    masked = _patch(R_TSTBR14, 0xFFFFFFFF, 0x2040, 0, 0x2000);
    assert masked == 0xFFF8021F , (
        f"imm14's mask disturbed bits outside the field: {masked}, want 0xFFF8021F"
    );
}

test "ADR's 21-bit displacement splits across immlo and immhi" {
    # `adr x0, .+7` (0x10000000): the low two bits go to immlo at 30:29 and the
    # rest to immhi at 23:5 -- the page-relative form's split without the >> 12.
    got = _patch(R_ADR_PREL_LO21, 0x10000000, 0x3007, 0, 0x3000);
    assert got == 0x70000020 , f"an ADR encoded as {got}, want 0x70000020";

    masked = _patch(R_ADR_PREL_LO21, 0xFFFFFFFF, 0x3007, 0, 0x3000);
    assert masked == 0xFF00003F , (
        f"ADR's mask disturbed bits outside its two fields: {masked}, want 0xFF00003F"
    );
}

test "ADRP answers for its checked and its no-check form alike" {
    # The _NC form differs only in that the assembler may skip the overflow
    # check; the bits a linker writes are identical, so both must be handled.
    checked = _patch(R_ADR_PREL_PG_HI21, 0x90000000, 0x5000, 0, 0x1000);
    unchecked = _patch(R_ADR_PREL_PG_HI21_NC, 0x90000000, 0x5000, 0, 0x1000);
    assert checked == 0x90000020 , f"ADRP encoded as {checked}, want 0x90000020";
    assert unchecked == checked , (
        f"the no-check ADRP form encoded as {unchecked}, not {checked} like its "
        "checked twin -- one of the two is unhandled"
    );
}

test "a displacement too far for its field is refused, not truncated" {
    # imm19 reaches +/-1 MiB and imm14 only +/-32 KiB, which a real .text can
    # outrun. Masking an over-long displacement into the field would encode a
    # branch to the wrong address in a binary that otherwise looks linked, and
    # this linker plants no range-extension veneers to fall back on.
    caught = "";
    try {
        _patch(R_CONDBR19, 0x54000001, 0x400000, 0, 0x1000);
    } except ValueError as exc {
        caught = str(exc);
    }
    assert "Refusing to emit a truncated branch" in caught , (
        f"a conditional branch 4 MiB away was encoded anyway: {caught}"
    );

    caught = "";
    try {
        _patch(R_TSTBR14, 0x36080000, 0x40000, 0, 0x2000);
    } except ValueError as exc {
        caught = str(exc);
    }
    assert "Refusing to emit a truncated branch" in caught , (
        f"a test-and-branch past imm14's reach was encoded anyway: {caught}"
    );

    # The reach itself must not shrink: a branch just inside imm19 still links.
    assert _patch(R_CONDBR19, 0x54000001, 0x1000 + 0xFFFFC, 0, 0x1000) is not None , (
        "a conditional branch just inside imm19's reach was refused"
    );
}

test "a relocation with no handler is still refused, not quietly skipped" {
    # The refusal is the safety property the handler table hangs off: widening
    # the table must not turn an unknown relocation into a silent no-op patch.
    assert _patch(0xDEAD, 0xFFFFFFFF, 0x1080, 0, 0x1000) is None , (
        "an unknown relocation type reported success; the linker would emit a "
        "binary with an unrelocated reference"
    );
}
