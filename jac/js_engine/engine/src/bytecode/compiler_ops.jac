"""Shared operator -> bytecode opcode mapping (replaces 3 duplicated switches)."""

import from engine.src.bytecode.op { Opcode }

"""Return opcode for binary/compound-assign operator string, or NOP if unknown."""
def:pub compiler_op_for_binary(op: str) -> Opcode {
    if op == "+" {
        return Opcode.ADD;
    } elif op == "-" {
        return Opcode.SUB;
    } elif op == "*" {
        return Opcode.MUL;
    } elif op == "/" {
        return Opcode.DIV;
    } elif op == "%" {
        return Opcode.MOD;
    } elif op == "**" {
        return Opcode.POW;
    } elif op == "<<" {
        return Opcode.SHL;
    } elif op == ">>" {
        return Opcode.SHR;
    } elif op == ">>>" {
        return Opcode.USHR;
    } elif op == "&" {
        return Opcode.BAND;
    } elif op == "|" {
        return Opcode.BOR;
    } elif op == "^" {
        return Opcode.BXOR;
    } elif op == "==" {
        return Opcode.EQ;
    } elif op == "!=" {
        return Opcode.NEQ;
    } elif op == "===" {
        return Opcode.STRICT_EQ;
    } elif op == "!==" {
        return Opcode.STRICT_NEQ;
    } elif op == "<" {
        return Opcode.LT;
    } elif op == "<=" {
        return Opcode.LTE;
    } elif op == ">" {
        return Opcode.GT;
    } elif op == ">=" {
        return Opcode.GTE;
    } elif op == "instanceof" {
        return Opcode.INSTANCEOF;
    } elif op == "in" {
        return Opcode.IN;
    }
    return Opcode.NOP;
}
