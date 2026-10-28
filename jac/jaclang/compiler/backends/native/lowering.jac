import json;

glob LOWERING_METADATA: str = "jac.native.lowering.v1",
     DEMOTED_SUFFIX: str = ".__jac_demoted",
     _HEX_DIGITS: str = "0123456789abcdef",
     _DEC_DIGITS: str = "0123456789",
     _BLANKS: str = " \t\r\f\v";

enum NativeLoweringKind { CALLABLE = "callable", FIELD = "field" }

def _lowering_kind(name: str) -> NativeLoweringKind;

obj NativeLoweringIssue {
    has symbol: str,
        kind: NativeLoweringKind,
        source: str,
        code: str,
        detail: str;

    def record(module: ir.Module);
}

def _skip_blanks(text: str, at: int) -> int;

def _node_references(operands: str) -> list[str];

def _lowering_roots(llvm_ir_text: str) -> list[str];

def _hex_nodes(llvm_ir_text: str) -> dict[str, str];

def native_lowering_issues(llvm_ir_text: str) -> list[NativeLoweringIssue];

obj NativeFallbacks {
    has symbols: list[str] = [],
        issues: list[NativeLoweringIssue] = [];

    def require;
}

def native_fallbacks(
    issues: list[NativeLoweringIssue], demoted_definitions: list[str]
) -> NativeFallbacks;

def _defined_symbol(line: str) -> str;

def native_fallbacks_in_ir(llvm_ir_text: str) -> NativeFallbacks;
