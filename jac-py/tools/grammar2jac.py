"""grammar2jac - emit Jac PEG parser rules from CPython's python.gram.

P0.7 backend for the pegen grammar model (PLAN.md). Reuses
reference/cpython/Tools/peg_generator to parse the frozen grammar, then emits
checked-in Jac rule functions that call peg_runtime + parser_actions.

Usage:
    python jac-py/tools/grammar2jac.py
    python jac-py/tools/grammar2jac.py --check
    python jac-py/tools/grammar2jac.py --stdout
"""

from __future__ import annotations

import argparse
import ast as py_ast
import os
import re
import sys
from collections.abc import Sequence
from io import StringIO
from typing import IO, Any

_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO = os.path.dirname(os.path.dirname(_HERE))
_PEGEN = os.path.join(_REPO, "reference", "cpython", "Tools", "peg_generator")
sys.path.insert(0, _PEGEN)
sys.path.insert(0, _HERE)

from action_translate import ActionTranslationError, ActionTranslator  # noqa: E402
from pegen.build import build_parser, generate_token_definitions  # noqa: E402
from pegen.grammar import (  # noqa: E402
    Alt,
    Cut,
    Forced,
    Gather,
    Grammar,
    GrammarVisitor,
    Group,
    Lookahead,
    NamedItem,
    NameLeaf,
    NegativeLookahead,
    Opt,
    PositiveLookahead,
    Repeat0,
    Repeat1,
    Rhs,
    Rule,
    StringLeaf,
)
from pegen.parser_generator import (  # noqa: E402
    KeywordCollectorVisitor,
    ParserGenerator,
    RuleCollectorVisitor,
)

GRAMMAR_PATH = os.path.join(_REPO, "reference", "cpython", "Grammar", "python.gram")
TOKENS_PATH = os.path.join(_REPO, "reference", "cpython", "Grammar", "Tokens")
OUT_PATH = os.path.join(_REPO, "jac-py", "jacpython", "parser.jac")
GRAMMAR_PROVENANCE = "reference/cpython/Grammar/python.gram"
START_RULES: list[str] = ["eval", "file"]


class GrammarTypeError(ValueError):
    """Raised when a grammar return type is not in the pinned type registry."""


JAC_TYPES: dict[str, str] = {
    "expr_ty": "expr",
    "mod_ty": "mod",
    "stmt_ty": "stmt",
    "pattern_ty": "pattern",
    "arguments_ty": "arguments",
    "alias_ty": "alias",
    "arg_ty": "arg",
    "comprehension_ty": "comprehension",
    "excepthandler_ty": "excepthandler",
    "match_case_ty": "match_case",
    "type_param_ty": "type_param",
    "withitem_ty": "withitem",
    "AugOperator*": "operator",
    "CmpopExprPair*": "pa_cmpop_expr_pair",
    "KeyValuePair*": "pa_key_value_pair",
    "KeyPatternPair*": "pa_key_pattern_pair",
    "KeywordOrStarred*": "pa_keyword_or_starred",
    "NameDefaultPair*": "pa_name_default_pair",
    "ResultTokenWithMetadata*": "peg_token",
    "SlashWithDefault*": "object",
    "StarEtc*": "object",
    "Token*": "peg_token",
    "asdl_alias_seq*": "list[alias]",
    "asdl_arg_seq*": "list[arg]",
    "asdl_comprehension_seq*": "list[comprehension]",
    "asdl_expr_seq*": "list[expr]",
    "asdl_identifier_seq*": "list[str]",
    "asdl_int_seq*": "list[cmpop]",
    "asdl_keyword_seq*": "list[keyword]",
    "asdl_pattern_seq*": "list[pattern]",
    "asdl_seq*": "list[object]",
    "asdl_stmt_seq*": "list[stmt]",
    "asdl_type_param_seq*": "list[type_param]",
}

BINOP_OPSBINOP_OPS = {
    "Add": "Add",
    "Sub": "Sub",
    "Mult": "Mult",
    "Div": "Div",
    "FloorDiv": "FloorDiv",
    "Mod": "Mod",
    "MatMult": "MatMult",
    "Pow": "Pow",
    "LShift": "LShift",
    "RShift": "RShift",
    "BitOr": "BitOr",
    "BitXor": "BitXor",
    "BitAnd": "BitAnd",
}

UNARY_OPS = {"UAdd": "UAdd", "USub": "USub", "Invert": "Invert", "Not": "Not"}
BOOL_OPS = {"And": "And", "Or": "Or"}
CMP_OPS = {
    "Eq": "Eq",
    "NotEq": "NotEq",
    "Lt": "Lt",
    "LtE": "LtE",
    "Gt": "Gt",
    "GtE": "GtE",
    "Is": "Is",
    "IsNot": "IsNot",
    "In": "In",
    "NotIn": "NotIn",
}

TOKEN_CALLS = {
    "NAME": ("name_var", "pa_name_from_token(peg_expect_token(p, NAME))"),
    "NUMBER": ("number_var", "pa_number_from_token(peg_expect_token(p, NUMBER))"),
    "STRING": ("string_var", "peg_expect_token(p, STRING)"),
    "OP": ("op_var", "peg_expect_token(p, OP)"),
}


def _refs_in_node(node: Any) -> set[str]:
    names: set[str] = set()

    def walk(n: Any) -> None:
        if isinstance(n, NameLeaf):
            names.add(n.value)
        elif hasattr(n, "__dict__"):
            for v in n.__dict__.values():
                if isinstance(v, list):
                    for x in v:
                        walk(x)
                elif v is not None and not isinstance(v, (str, int, bool)):
                    walk(v)

    walk(node)
    return names


def _alt_uses_rule(alt: Alt, name: str) -> bool:
    return name in _refs_in_node(alt)


def jac_type(c_type: str | None, *, is_seq: bool = False) -> str:
    if c_type is None:
        return "object"
    if c_type in JAC_TYPES:
        return JAC_TYPES[c_type]
    if c_type.endswith("*"):
        inner_name = c_type[:-1]
        if inner_name in JAC_TYPES:
            inner = JAC_TYPES[inner_name]
        elif inner_name.endswith("_ty"):
            inner = inner_name[: -len("_ty")]
        else:
            raise GrammarTypeError(f"unknown pointer grammar type: {c_type!r}")
        if inner.startswith("list["):
            return inner
        return f"list[{inner}]"
    raise GrammarTypeError(f"unknown grammar type: {c_type!r}")


def jac_cast_type(ret: str) -> str:
    return ret.replace(" | None", "").strip()


def jac_return_type(c_type: str | None, *, is_seq: bool = False) -> str:
    base = jac_type(c_type, is_seq=is_seq)
    if base.endswith("| None"):
        return base
    return f"{base} | None"


def _rule_fn(name: str) -> str:
    return f"rule_{name}"


class JacCallMakerVisitor(GrammarVisitor):
    def __init__(self, gen: "JacParserGenerator", exact_tokens: dict[str, int]) -> None:
        self.gen = gen
        self.exact_tokens = exact_tokens
        self.cache: dict[str, tuple[str, str]] = {}

    def visit_NameLeaf(self, node: NameLeaf) -> tuple[str | None, str]:
        name = node.value
        if name == "SOFT_KEYWORD":
            return "soft_kw", "peg_expect_soft_keyword(p, \"\")"
        if name in TOKEN_CALLS:
            var, call = TOKEN_CALLS[name]
            return var, call
        if name in ("NEWLINE", "DEDENT", "INDENT", "ENDMARKER"):
            return f"_{name.lower()}", f"peg_expect_token(p, {name})"
        if name in self.gen.tokens:
            return f"{name.lower()}_tok", f"peg_expect_token(p, {name})"
        return name, f"{_rule_fn(name)}(p)"

    def visit_StringLeaf(self, node: StringLeaf) -> tuple[str, str]:
        val = py_ast.literal_eval(node.value)
        if re.match(r"[a-zA-Z_]\w*\Z", val):
            if node.value.endswith("'"):
                kw = self.gen.keywords[val]
                return "kw", f"peg_expect_token(p, {kw})"
            return "soft", f"peg_expect_soft_keyword(p, {node.value})"
        tok = self.exact_tokens[val]
        return "lit", f"peg_expect_token(p, {tok})"

    def visit_NamedItem(self, node: NamedItem) -> tuple[str | None, str]:
        name, call = self.visit(node.item)
        if node.name:
            name = node.name
        return name, call

    def _lookahead_token_expr(self, node: Any) -> str | None:
        if isinstance(node, NameLeaf):
            name = node.value
            if name in TOKEN_CALLS:
                _, call = TOKEN_CALLS[name]
                return call
            if name in ("NEWLINE", "DEDENT", "INDENT", "ENDMARKER"):
                return f"peg_expect_token(p, {name})"
            if name in self.gen.tokens:
                return f"peg_expect_token(p, {name})"
            return None
        if isinstance(node, StringLeaf):
            _, inner = self.visit(node)
            if "peg_expect_token(p," in inner:
                tok = inner.split("peg_expect_token(p, ")[1].rstrip(")")
                return f"peg_expect_token(p, {tok})"
            return None
        if isinstance(node, Group):
            return self._lookahead_token_expr(node.rhs)
        if isinstance(node, Rhs):
            parts: list[str] = []
            for alt in node.alts:
                if len(alt.items) != 1:
                    return None
                part = self._lookahead_token_expr(alt.items[0].item)
                if part is None:
                    return None
                parts.append(part)
            if not parts:
                return None
            if len(parts) == 1:
                return parts[0]
            return "(" + " or ".join(parts) + ")"
        return None

    def visit_PositiveLookahead(self, node: PositiveLookahead) -> tuple[None, str]:
        token_expr = self._lookahead_token_expr(node.node)
        if token_expr is not None:
            if token_expr.startswith("(") and " or " in token_expr:
                parts = token_expr[1:-1].split(" or ")
                checks = [
                    "peg_positive_lookahead_token(p, "
                    + p.split("peg_expect_token(p, ")[1].rstrip(")")
                    + ")"
                    for p in parts
                ]
                return None, "(" + " or ".join(checks) + ")"
            tok = token_expr.split("peg_expect_token(p, ")[1].rstrip(")")
            return None, f"peg_positive_lookahead_token(p, {tok})"
        _, inner = self.visit(node.node)
        if "peg_expect_token(p," in inner:
            tok = inner.split("peg_expect_token(p, ")[1].rstrip(")")
            return None, f"peg_positive_lookahead_token(p, {tok})"
        return None, f"({inner} is not None)"

    def visit_NegativeLookahead(self, node: NegativeLookahead) -> tuple[None, str]:
        token_expr = self._lookahead_token_expr(node.node)
        if token_expr is not None:
            if token_expr.startswith("(") and " or " in token_expr:
                parts = token_expr[1:-1].split(" or ")
                checks = [
                    "peg_negative_lookahead_token(p, "
                    + p.split("peg_expect_token(p, ")[1].rstrip(")")
                    + ")"
                    for p in parts
                ]
                return None, "(" + " and ".join(checks) + ")"
            tok = token_expr.split("peg_expect_token(p, ")[1].rstrip(")")
            return None, f"peg_negative_lookahead_token(p, {tok})"
        _, inner = self.visit(node.node)
        if "peg_expect_token(p," in inner:
            tok = inner.split("peg_expect_token(p, ")[1].rstrip(")")
            return None, f"peg_negative_lookahead_token(p, {tok})"
        return None, f"({inner} is None)"

    def visit_Opt(self, node: Opt) -> tuple[str, str]:
        name, call = self.visit(node.node)
        return name or "opt", call

    def _artificial(
        self, node: Any, prefix: str, maker: Any, trailing_comma: bool = False
    ) -> tuple[str, str]:
        key = f"{prefix}_{node}"
        if key in self.cache:
            return self.cache[key]
        rule_name = maker()
        call = f"{_rule_fn(rule_name)}(p)" + ("," if trailing_comma else "")
        self.cache[key] = (rule_name, call)
        return rule_name, call

    def visit_Rhs(self, node: Rhs) -> tuple[str, str]:
        if len(node.alts) == 1 and len(node.alts[0].items) == 1:
            return self.visit(node.alts[0].items[0])
        _, call = self._artificial(node, "rhs", lambda: self.gen.artificial_rule_from_rhs(node))
        return "rhs", call

    def visit_Repeat0(self, node: Repeat0) -> tuple[str, str]:
        _, call = self._artificial(
            node,
            "repeat0",
            lambda: self.gen.artificial_rule_from_repeat(node.node, is_repeat1=False),
            trailing_comma=False,
        )
        return "seq", call

    def visit_Repeat1(self, node: Repeat1) -> tuple[str, str]:
        _, call = self._artificial(
            node,
            "repeat1",
            lambda: self.gen.artificial_rule_from_repeat(node.node, is_repeat1=True),
        )
        return "seq", call

    def visit_Gather(self, node: Gather) -> tuple[str, str]:
        _, call = self._artificial(
            node, "gather", lambda: self.gen.artificial_rule_from_gather(node)
        )
        return "gather", call

    def visit_Group(self, node: Group) -> tuple[str | None, str]:
        return self.visit(node.rhs)

    def visit_Cut(self, node: Cut) -> tuple[str, str]:
        return "cut", "True"

    def visit_Forced(self, node: Forced) -> tuple[str, str]:
        if isinstance(node.node, StringLeaf):
            val = py_ast.literal_eval(node.node.value)
            tok = self.exact_tokens[val]
            return (
                "forced",
                f"peg_expect_forced_token(p, {tok}, '{val}')",
            )
        if isinstance(node.node, Group):
            _, inner = self.visit(node.node.rhs)
            rhs_s = str(node.node.rhs).replace('"', '\\"')
            return (
                "forced",
                f'peg_expect_forced_result(p, {inner}, "{rhs_s}")',
            )
        raise NotImplementedError(f"forced node {node.node!r}")


class JacParserGenerator(ParserGenerator, GrammarVisitor):
    def __init__(
        self,
        grammar: Grammar,
        tokens: set[str],
        file: IO[str] | None,
        *,
        allowed_rules: set[str] | None = None,
    ) -> None:
        super().__init__(grammar, tokens, file)
        self.allowed_rules = allowed_rules
        self.exact_token_map: dict[str, int] = {}
        self.callmakervisitor = JacCallMakerVisitor(self, self.exact_token_map)
        self.action_translator = ActionTranslator()
        self.rule_ids: dict[str, int] = {}
        self._rule_name = ""
        self._rule_ret = "object | None"
        self._rule_memo = False

    def set_exact_tokens(self, exact: dict[str, int]) -> None:
        self.exact_token_map = exact
        self.callmakervisitor.exact_tokens = exact

    def collect_rules(self) -> None:
        """Collect artificial rules in stable order for deterministic output."""
        keyword_collector = KeywordCollectorVisitor(
            self, self.keywords, self.soft_keywords
        )
        for rule in sorted(self.all_rules.values(), key=lambda r: r.name):
            keyword_collector.visit(rule)

        rule_collector = RuleCollectorVisitor(self.rules, self.callmakervisitor)
        done: set[str] = set()
        while True:
            todo = sorted(n for n in self.all_rules if n not in done)
            if not todo:
                break
            done = set(self.all_rules)
            for rulename in todo:
                rule_collector.visit(self.all_rules[rulename])

    def generate(self, filename: str) -> None:
        self.collect_rules()
        rules_to_emit = sorted(
            (r for r in self.all_rules.values() if self._emit_rule(r.name)),
            key=lambda r: r.name,
        )
        for i, rule in enumerate(rules_to_emit):
            self.rule_ids[rule.name] = i
        self._emit_header(filename)
        self._emit_rule_constants(rules_to_emit)
        for rule in rules_to_emit:
            self.visit(rule)
        self._emit_keywords()
        self._emit_entry_points()

    def _emit_rule(self, name: str) -> bool:
        # Artificial helpers (_loop*, _gather*, _tmp*) are created during
        # collect_rules() and must always be emitted (cpython pegen does the same).
        if name.startswith("_"):
            return True
        if self.allowed_rules is None:
            return True
        return name in self.allowed_rules

    def _emit_header(self, filename: str) -> None:
        base = os.path.basename(filename)
        self.print('"""jacpython generated PEG parser (unified eval + file profile).')
        self.print("")
        self.print(
            f"GENERATED by jac-py/tools/grammar2jac.py from {GRAMMAR_PROVENANCE}"
        )
        self.print(f"(starts: eval, file; source tag: {base}). Do not edit by hand.")
        self.print('"""')
        self.print("")
        self.print("import from token_model {")
        self.print(
            "    ENDMARKER, NAME, NUMBER, STRING, OP, NT_OFFSET, NEWLINE, TYPE_COMMENT,"
        )
        self.print(
            "    INDENT, DEDENT, FSTRING_START, FSTRING_MIDDLE, FSTRING_END,"
        )
        self.print(
            "    TSTRING_START, TSTRING_MIDDLE, TSTRING_END,"
        )
        self.print("}")
        self.print("import from peg_runtime {")
        self.print("    peg_parser, peg_parser_from_source, peg_set_keywords,")
        self.print("    peg_set_soft_keywords, peg_keyword_entry, peg_mark, peg_reset,")
        self.print("    peg_check_memo, peg_insert_memo, peg_update_memo,")
        self.print("    peg_expect_token, peg_expect_soft_keyword, peg_expect_forced_token,")
        self.print("    peg_expect_forced_result, peg_has_error, peg_fill_token,")
        self.print("    peg_positive_lookahead_token, peg_negative_lookahead_token,")
        self.print("    peg_left_rec_finish, peg_token,")
        self.print("}")
        self.print("import from parser_actions {")
        self.print("    pa_cmpop_expr_pair, pa_key_value_pair, pa_key_pattern_pair, pa_keyword_or_starred,")
        self.print("    pa_name_default_pair, pa_make_cmpop_pair, pa_name_from_token, pa_name_id, pa_number_from_token,")
        self.print("    pa_ast_expression, pa_ast_binop, pa_ast_unaryop, pa_ast_boolop, pa_ast_compare, pa_ast_call,")
        self.print("    pa_ast_ifexp, pa_constant_bool, pa_constant_none, pa_constant_from_expr, pa_singleton_seq, pa_stmt_list_or_empty,")
        self.print("    pa_seq_insert_front, pa_seq_append_to_end, pa_get_cmpops, pa_get_exprs, pa_get_keys, pa_get_values,")
        self.print("    pa_get_patterns, pa_get_pattern_keys, pa_collect_call_seqs, pa_call_from_optional_args,")
        self.print("    pa_ast_starred, pa_check, pa_make_module, pa_seq_flatten, pa_set_context, pa_map_names_to_ids,")
        self.print("    pa_ast_expr_stmt, pa_ast_assign, pa_ast_annassign, pa_ast_return, pa_ast_pass, pa_ast_break,")
        self.print("    pa_ast_continue, pa_ast_tuple, pa_ast_attribute, pa_ast_subscript, pa_ast_slice, pa_ast_augassign,")
        self.print("    pa_ast_delete, pa_raise_syntax, pa_raise_syntax_known_expr, pa_raise_syntax_known_range,")
        self.print("    pa_raise_invalid_target, pa_aug_op, pa_call_args, pa_call_keywords, pa_comp_field,")
        self.print("    pa_empty_arguments, pa_dummy_name, pa_interactive_exit, pa_seq_count_dots, pa_seq_first,")
        self.print("    pa_seq_last, pa_seq_len, pa_seq_get, pa_or_pattern_singleton, pa_check_legacy_stmt_or_raise,")
        self.print("    pa_raise_type_param_error, pa_raise_kvpair_error, pa_checked_future_import, pa_nonparen_genexp_in_call,")
        self.print("    pa_arguments_parsing_error, pa_check_legacy_stmt, pa_concatenate_strings, pa_concatenate_tstrings,")
        self.print("    pa_constant_from_string, pa_constant_from_token, pa_decoded_constant_from_token, pa_ensure_imaginary,")
        self.print("    pa_ensure_real, pa_get_expr_name, pa_get_last_comprehension_item, pa_join_names_with_dot,")
        self.print("    pa_join_sequences, pa_alias_for_star, pa_add_type_comment_to_arg, pa_seq_delete_starred_exprs,")
        self.print("    pa_seq_extract_starred_exprs, pa_setup_full_format_spec, pa_check_fstring_conversion,")
        self.print("    pa_function_def_decorators, pa_class_def_decorators, pa_make_arguments, pa_star_etc, pa_slash_with_default,")
        self.print("    pa_joined_str, pa_template_str, pa_formatted_value, pa_interpolation, pa_err_occurred,")
        self.print("    pa_expr_lineno, pa_expr_end_col_offset, pa_expr_end_lineno,")
        self.print("}")
        self.print("import from ast_nodes {")
        self.print("    ast_node, expr, mod, stmt, pattern, operator, cmpop, expr_context,")
        self.print("    arguments, alias, arg, keyword, comprehension, excepthandler, match_case, type_param, withitem,")
        self.print("    Expression, Interactive, FunctionType, Module, Name, Load, Store, Del,")
        self.print("    Assign, AnnAssign, AugAssign, Expr, Return, Pass, Break, Continue, Delete, Raise,")
        self.print("    Import, ImportFrom, Global, Nonlocal, Assert, If, For, AsyncFor, While, With, AsyncWith,")
        self.print("    FunctionDef, AsyncFunctionDef, ClassDef, Try, TryStar, ExceptHandler, Match, TypeAlias,")
        self.print("    Attribute, Subscript, Slice, Tuple, List, Dict, Set, Starred, NamedExpr, Lambda,")
        self.print("    BinOp, UnaryOp, BoolOp, Compare, Call, IfExp, Await, Yield, YieldFrom,")
        self.print("    ListComp, SetComp, DictComp, GeneratorExp, Constant, JoinedStr, TemplateStr,")
        self.print("    FormattedValue, Interpolation, MatchAs, MatchOr, MatchSequence, MatchMapping, MatchClass,")
        self.print("    MatchStar, MatchSingleton, MatchValue,")
        self.print("    Add, Sub, Mult, Div, FloorDiv, Mod, MatMult, Pow, LShift, RShift, BitOr, BitXor, BitAnd,")
        self.print("    USub, UAdd, Not, Invert, Or, And, Lt, LtE, Gt, GtE, Eq, NotEq, In, IsNot, Is,")
        self.print("}")
        self.print("")

    def _emit_rule_constants(self, rules: Sequence[Rule]) -> None:
        parts = [f"RULE_{r.name}: int = NT_OFFSET + {i}" for i, r in enumerate(rules)]
        self.print("glob " + parts[0] + ",")
        for part in parts[1:-1]:
            self.print(f"     {part},")
        if len(parts) > 1:
            self.print(f"     {parts[-1]};")
        else:
            self.print(";")
        self.print("")

    def _emit_keywords(self) -> None:
        self.print("def _build_keyword_lists() -> list[list[peg_keyword_entry]] {")
        with self.indent():
            max_len = 0
            for spelling in self.keywords:
                max_len = max(max_len, len(spelling))
            self.print(f"lists: list[list[peg_keyword_entry]] = [];")
            self.print(f"i = 0;")
            self.print(f"while i <= {max_len} {{")
            with self.indent():
                self.print("lists.append([]);")
                self.print("i = i + 1;")
            self.print("}")
            for spelling, tok_id in sorted(self.keywords.items(), key=lambda x: len(x[0])):
                self.print(
                    f'lists[{len(spelling)}].append(peg_keyword_entry(spelling="{spelling}", tok_type={tok_id}));'
                )
            self.print("return lists;")
        self.print("}")
        soft = sorted(self.soft_keywords)
        soft_quoted = ", ".join(f'"{s}"' for s in soft)
        self.print(f"glob SOFT_KEYWORDS: list[str] = [{soft_quoted}];")
        self.print("")

    def _emit_entry_points(self) -> None:
        self.print("def parse_eval_module(p: peg_parser) -> mod | None {")
        with self.indent():
            self.print("res = rule_eval(p);")
            self.print("if res is None {")
            with self.indent():
                self.print("return None;")
            self.print("}")
            self.print("if peg_expect_token(p, ENDMARKER) is None {")
            with self.indent():
                self.print("return None;")
            self.print("}")
            self.print("return res;")
        self.print("}")
        self.print("")
        self.print("def parse_eval_source(source: str, filename: str) -> mod | None {")
        with self.indent():
            self.print("p = peg_parser_from_source(source, filename, True);")
            self.print("peg_set_keywords(p, _build_keyword_lists());")
            self.print("peg_set_soft_keywords(p, SOFT_KEYWORDS);")
            self.print("return parse_eval_module(p);")
        self.print("}")
        self.print("")
        self.print("def parse_eval_expr(source: str, filename: str) -> expr | None {")
        with self.indent():
            self.print("mod = parse_eval_source(source, filename);")
            self.print("if mod is None {")
            with self.indent():
                self.print("return None;")
            self.print("}")
            self.print("if isinstance(mod, Expression) {")
            with self.indent():
                self.print("return (mod as Expression).body;")
            self.print("}")
            self.print("return None;")
        self.print("}")
        self.print("")
        self.print("def parse_file_module(p: peg_parser) -> mod | None {")
        with self.indent():
            self.print("res = rule_file(p);")
            self.print("if res is None {")
            with self.indent():
                self.print("return None;")
            self.print("}")
            self.print("if peg_expect_token(p, ENDMARKER) is None {")
            with self.indent():
                self.print("return None;")
            self.print("}")
            self.print("return res;")
        self.print("}")
        self.print("")
        self.print("def parse_file_source(source: str, filename: str) -> mod | None {")
        with self.indent():
            self.print("p = peg_parser_from_source(source, filename, True);")
            self.print("peg_set_keywords(p, _build_keyword_lists());")
            self.print("peg_set_soft_keywords(p, SOFT_KEYWORDS);")
            self.print("return parse_file_module(p);")
        self.print("}")
        self.print("")
        self.print("def parse_file(source: str, filename: str) -> Module | None {")
        with self.indent():
            self.print("mod = parse_file_source(source, filename);")
            self.print("if mod is None {")
            with self.indent():
                self.print("return None;")
            self.print("}")
            self.print("if isinstance(mod, Module) {")
            with self.indent():
                self.print("return mod as Module;")
            self.print("}")
            self.print("return None;")
        self.print("}")

    def _alt_starts_with_rule(self, alt: Alt, rule_name: str) -> bool:
        if not alt.items:
            return False
        item = alt.items[0].item
        if isinstance(item, Rule):
            return item.name == rule_name
        if isinstance(item, NameLeaf):
            return item.value == rule_name
        return False

    def _function_def_raw_rhs(self, rhs: Rhs) -> Rhs:
        invalid: list[Alt] = []
        rest: list[Alt] = []
        for alt in rhs.alts:
            if self._alt_starts_with_rule(alt, "invalid_def_raw"):
                invalid.append(alt)
            else:
                rest.append(alt)
        return Rhs(alts=rest + invalid)

    def visit_Rule(self, node: Rule) -> None:
        is_loop = node.is_loop()
        is_gather = node.is_gather()
        rhs = node.flatten()
        if node.name == "function_def_raw":
            rhs = self._function_def_raw_rhs(rhs)
        ret = jac_return_type(node.type, is_seq=is_loop or is_gather)
        rule_id = self.rule_ids[node.name]
        if node.left_recursive and node.leader:
            self._emit_left_rec_leader(node, rhs, ret, rule_id)
            return
        if node.left_recursive:
            self.print(f"def {_rule_fn(node.name)}(p: peg_parser) -> {ret} {{")
            with self.indent():
                self.print(f"return {_rule_fn(node.name)}_raw(p);")
            self.print("}")
            self.print("")
            self._emit_left_rec_raw(node, rhs, ret)
            return
        memo = node.memo and not node.left_recursive
        self.print(f"def {_rule_fn(node.name)}(p: peg_parser) -> {ret} {{")
        with self.indent():
            if memo:
                self.print(f"hit = peg_check_memo(p, RULE_{node.name});")
                self.print("if hit.hit {")
                with self.indent():
                    self.print(f"return hit.result as {jac_cast_type(ret)};")
                self.print("}")
            self.print("mark = peg_mark(p);")
            if self._uses_extra(rhs):
                self.print("start_lineno = 1;")
                self.print("start_col_offset = 0;")
                self.print("end_lineno = 1;")
                self.print("end_col_offset = 0;")
                self.print("if peg_fill_token(p) {")
                with self.indent():
                    self.print("t0 = p.tokens[p.mark];")
                    self.print("start_lineno = t0.lineno;")
                    self.print("start_col_offset = t0.col_offset;")
                self.print("}")
            if is_loop:
                self.print("children: list[object] = [];")
            self._rule_name = node.name
            self._rule_ret = ret
            self._rule_memo = memo
            self.visit(rhs, is_loop=is_loop, is_gather=is_gather)
            if is_loop:
                if node.name.startswith("_loop1"):
                    self.print("if len(children) == 0 {")
                    with self.indent():
                        self.print("return None;")
                    self.print("}")
                self.print("return children as list[expr];")
            else:
                if memo:
                    self.print(f"peg_insert_memo(p, mark, RULE_{node.name}, None);")
                self.print("return None;")
        self.print("}")
        self.print("")

    def _emit_left_rec_leader(self, node: Rule, rhs: Rhs, ret: str, rule_id: int) -> None:
        self.print(f"def {_rule_fn(node.name)}(p: peg_parser) -> {ret} {{")
        with self.indent():
            self.print(f"hit = peg_check_memo(p, RULE_{node.name});")
            self.print("if hit.hit {")
            with self.indent():
                self.print(f"return hit.result as {ret};")
            self.print("}")
            self.print("mark = peg_mark(p);")
            self.print(f"res: {ret} = None;")
            self.print("resmark = mark;")
            self.print("while True {")
            with self.indent():
                self.print(f"peg_update_memo(p, mark, RULE_{node.name}, res);")
                self.print("peg_reset(p, mark);")
                self.print(f"raw = {_rule_fn(node.name)}_raw(p);")
                self.print("if peg_has_error(p) {")
                with self.indent():
                    self.print("return None;")
                self.print("}")
                self.print("if raw is None or peg_mark(p) <= resmark {")
                with self.indent():
                    self.print("break;")
                self.print("}")
                self.print("resmark = peg_mark(p);")
                self.print("res = raw;")
            self.print("}")
            self.print(f"return peg_left_rec_finish(p, resmark, res) as {jac_cast_type(ret)};")
        self.print("}")
        self.print("")
        self._emit_left_rec_raw(node, rhs, ret)

    def _emit_left_rec_raw(self, node: Rule, rhs: Rhs, ret: str) -> None:
        self.print(f"def {_rule_fn(node.name)}_raw(p: peg_parser) -> {ret} {{")
        with self.indent():
            self._rule_name = node.name
            self._rule_memo = False
            self.print("mark = peg_mark(p);")
            if self._uses_extra(rhs):
                self.print("start_lineno = 1;")
                self.print("start_col_offset = 0;")
                self.print("end_lineno = 1;")
                self.print("end_col_offset = 0;")
            self.visit(rhs, is_loop=False, is_gather=False)
            self.print("return None;")
        self.print("}")
        self.print("")

    def _uses_extra(self, rhs: Rhs) -> bool:
        # Actions that emit start_lineno/col_offset/end_* via action_translate LOC.
        loc_actions = (
            "_PyPegen_dummy_name",
            "_PyPegen_collect_call_seqs",
            "_PyPegen_key_value_pair",
            "_PyPegen_key_pattern_pair",
            "_PyPegen_name_default_pair",
            "_PyPegen_keyword_or_starred",
            "_PyPegen_make_arguments",
            "_PyPegen_star_etc",
            "_PyPegen_slash_with_default",
            "_PyPegen_joined_str",
            "_PyPegen_template_str",
            "_PyPegen_formatted_value",
            "_PyPegen_interpolation",
            "_PyAST_Call",
            "_PyAST_Constant",
            "_PyAST_AnnAssign",
            "_PyAST_Pass",
            "_PyAST_Break",
            "_PyAST_Continue",
            "_PyAST_Return",
            "_PyAST_Tuple",
            "_PyAST_Attribute",
            "_PyAST_Subscript",
            "_PyAST_Slice",
            "_PyAST_AugAssign",
            "_PyAST_Delete",
        )
        for alt in rhs.alts:
            if alt.action and (
                "EXTRA" in alt.action
                or any(marker in alt.action for marker in loc_actions)
            ):
                return True
        return False

    def visit_Rhs(
        self,
        node: Rhs,
        *,
        is_loop: bool = False,
        is_gather: bool = False,
    ) -> None:
        for alt in node.alts:
            self.visit(alt, is_loop=is_loop, is_gather=is_gather)
            if not is_loop:
                self.print("peg_reset(p, mark);")

    def visit_Alt(self, node: Alt, is_loop: bool = False, is_gather: bool = False) -> None:
        if is_loop:
            self._visit_alt_loop(node, is_gather)
            return
        has_cut = any(isinstance(i.item, Cut) for i in node.items)
        with self.local_variable_context():
            self._emit_alt_body_nested(node.items, 0, node, is_gather, has_cut)

    def _emit_alt_body_nested(
        self,
        items: list,
        idx: int,
        node: Alt,
        is_gather: bool,
        has_cut: bool,
    ) -> None:
        if idx >= len(items):
            if node.action and "EXTRA" in node.action:
                self.print("end_tok = p.tokens[p.mark - 1];")
                self.print("end_lineno = end_tok.end_lineno;")
                self.print("end_col_offset = end_tok.end_col_offset;")
            action = self._emit_action(node, is_gather)
            self.print(f"res = {action};")
            if self._rule_memo:
                self.print(f"peg_insert_memo(p, mark, RULE_{self._rule_name}, res);")
            self.print("return res;")
            return
        item = items[idx]
        if isinstance(item.item, Cut):
            self.print("cut = True;")
            self._emit_alt_body_nested(items, idx + 1, node, is_gather, has_cut)
            return
        if isinstance(item.item, Opt):
            name, call = self.callmakervisitor.visit(item)
            v = self.dedupe(name if name else "opt")
            call_clean = call[:-1] if call.endswith(",") else call
            self.print(f"{v} = {call_clean};")
            self._emit_alt_body_nested(items, idx + 1, node, is_gather, has_cut)
            return
        name, call = self.callmakervisitor.visit(item)
        if name == "cut":
            self._emit_alt_body_nested(items, idx + 1, node, is_gather, has_cut)
            return
        if name:
            v = self.dedupe(name)
            call_clean = call[:-1] if call.endswith(",") else call
            self.print(f"{v} = {call_clean};")
            self.print(f"if {v} is not None {{")
            with self.indent():
                self._emit_alt_body_nested(items, idx + 1, node, is_gather, has_cut)
            self.print("}")
            return
        self.print(f"if ({call}) {{")
        with self.indent():
            self._emit_alt_body_nested(items, idx + 1, node, is_gather, has_cut)
        self.print("}")

    def _visit_alt_loop(self, node: Alt, is_gather: bool) -> None:
        has_cut = any(isinstance(i.item, Cut) for i in node.items)
        if has_cut:
            self.print("cut = False;")
        self.print("while True {")
        with self.indent():
            self.print("comma_mark = peg_mark(p);")
            with self.local_variable_context():
                self._emit_loop_body_nested(node.items, 0, node, is_gather, has_cut)
        self.print("}")

    def _emit_loop_body_nested(
        self,
        items: list,
        idx: int,
        node: Alt,
        is_gather: bool,
        has_cut: bool,
    ) -> None:
        if idx >= len(items):
            if node.action and "EXTRA" in node.action:
                self.print("end_tok = p.tokens[p.mark - 1];")
                self.print("end_lineno = end_tok.end_lineno;")
                self.print("end_col_offset = end_tok.end_col_offset;")
            action = self._emit_action(node, is_gather)
            self.print(f"children.append({action});")
            self.print("mark = peg_mark(p);")
            return
        item = items[idx]
        if isinstance(item.item, Cut):
            self.print("cut = True;")
            self._emit_loop_body_nested(items, idx + 1, node, is_gather, has_cut)
            return
        name, call = self.callmakervisitor.visit(item)
        if name == "cut":
            self._emit_loop_body_nested(items, idx + 1, node, is_gather, has_cut)
            return
        if name:
            v = self.dedupe(name)
            call_clean = call[:-1] if call.endswith(",") else call
            self.print(f"{v} = {call_clean};")
            self.print(f"if {v} is None {{")
            with self.indent():
                if idx > 0:
                    self.print("peg_reset(p, comma_mark);")
                self.print("break;")
            self.print("}")
            self._emit_loop_body_nested(items, idx + 1, node, is_gather, has_cut)
            return
        self.print(f"if not ({call}) {{")
        with self.indent():
            if idx > 0:
                self.print("peg_reset(p, comma_mark);")
            self.print("break;")
        self.print("}")
        self._emit_loop_body_nested(items, idx + 1, node, is_gather, has_cut)

    def _emit_action(self, node: Alt, is_gather: bool) -> str:
        if node.action:
            try:
                return self.action_translator.translate(node.action)
            except ActionTranslationError as err:
                raise ActionTranslationError(f"in alt {node!s}: {err}") from err
        names = list(self.local_variable_names)
        if is_gather:
            return f"pa_seq_insert_front({names[0]}, {names[1]})"
        # Trailing peg_expect_token captures (lit, lit_1, ...) are not semantic
        # values; match CPython gather/repeat element actions that return only z.
        semantic = [n for n in names if not n.startswith("lit")]
        if len(semantic) == 1:
            return semantic[0]
        if len(names) == 1:
            return names[0]
        return f"[{', '.join(names)}]"


def load_token_sets() -> tuple[set[str], dict[str, int]]:
    with open(TOKENS_PATH) as fh:
        _, exact, non_exact = generate_token_definitions(fh)
    tokens = set(non_exact) | set(exact.keys())
    return tokens, exact


def _reorder_simple_stmt(rule: Rule) -> Rule:
    order = ("assignment", "return_stmt", "pass_stmt", "del_stmt", "star_expressions")
    buckets: dict[str, list[Alt]] = {name: [] for name in order}
    other: list[Alt] = []
    for alt in rule.rhs.alts:
        refs = _refs_in_node(alt)
        placed = False
        for name in order:
            if name in refs:
                buckets[name].append(alt)
                placed = True
                break
        if not placed:
            other.append(alt)
    kept: list[Alt] = []
    for name in order:
        kept.extend(buckets[name])
    kept.extend(other)
    return Rule(rule.name, rule.type, Rhs(kept), rule.memo)


def prepare_grammar(grammar: Grammar) -> Grammar:
    rules = dict(grammar.rules)
    if "simple_stmt" in rules:
        rules["simple_stmt"] = _reorder_simple_stmt(rules["simple_stmt"])
    return Grammar(rules.values(), grammar.metas.items())


def generate_text() -> str:
    grammar, _, _ = build_parser(GRAMMAR_PATH)
    grammar = prepare_grammar(grammar)
    tokens, exact = load_token_sets()
    buf = StringIO()
    gen = JacParserGenerator(grammar, tokens, buf, allowed_rules=None)
    gen.set_exact_tokens(exact)
    gen.generate(OUT_PATH)
    return _patch_store_target_rules(buf.getvalue())


def _patch_store_target_rules(source: str) -> str:
    """Store targets use atom, not t_primary: t_primary consumes .attr for loads."""
    rules = (
        "def rule_target_with_star_atom",
        "def rule_single_subscript_attribute_target",
    )
    out: list[str] = []
    in_rule = False
    for line in source.splitlines(keepends=True):
        if any(line.startswith(f"{r}(p:") for r in rules):
            in_rule = True
        elif in_rule and line.startswith("def rule_"):
            in_rule = False
        if in_rule and "a = rule_t_primary(p)" in line:
            line = line.replace("a = rule_t_primary(p)", "a = rule_atom(p)")
        out.append(line)
    return "".join(out)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Emit Jac parser from python.gram")
    parser.add_argument("--stdout", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    text = generate_text()
    if args.stdout:
        sys.stdout.write(text)
        return 0
    if args.check:
        try:
            on_disk = open(OUT_PATH).read()
        except FileNotFoundError:
            print(f"{OUT_PATH} missing; run grammar2jac.py", file=sys.stderr)
            return 1
        if on_disk != text:
            print(f"{OUT_PATH} is stale; regenerate with grammar2jac.py", file=sys.stderr)
            return 1
        print(f"{OUT_PATH} up to date")
        return 0
    with open(OUT_PATH, "w") as fh:
        fh.write(text)
    print(f"wrote {OUT_PATH} ({len(text.splitlines())} lines)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
