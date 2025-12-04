"""Jac compiler tools and parser generation utilities."""

import logging
import os
import shutil
import sys

_vendor_dir = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "vendor"))
if _vendor_dir not in sys.path:
    sys.path.insert(0, _vendor_dir)

_cur_dir = os.path.dirname(__file__)


def generate_static_parser(force: bool = False) -> None:
    """Generate static parser for Jac."""
    from lark.tools import standalone

    larkparse_dir = os.path.join(_cur_dir, "larkparse")
    if force or not os.path.exists(os.path.join(larkparse_dir, "jac_parser.py")):
        if os.path.exists(larkparse_dir):
            shutil.rmtree(larkparse_dir)
        os.makedirs(larkparse_dir, exist_ok=True)
        open(os.path.join(larkparse_dir, "__init__.py"), "w").close()
        sys.argv, save = (
            [
                "lark",
                os.path.join(_cur_dir, "jac.lark"),
                "-o",
                os.path.join(larkparse_dir, "jac_parser.py"),
                "-c",
            ],
            sys.argv,
        )
        standalone.main()
        sys.argv = save


def generate_ts_static_parser(force: bool = False) -> None:
    """Generate static parser for TypeScript/JavaScript."""
    from lark.tools import standalone

    larkparse_dir = os.path.join(_cur_dir, "larkparse")
    ts_parser_path = os.path.join(larkparse_dir, "ts_parser.py")
    if force or not os.path.exists(ts_parser_path):
        os.makedirs(larkparse_dir, exist_ok=True)
        init_path = os.path.join(larkparse_dir, "__init__.py")
        if not os.path.exists(init_path):
            open(init_path, "w").close()
        sys.argv, save = (
            ["lark", os.path.join(_cur_dir, "ts.lark"), "-o", ts_parser_path, "-c"],
            sys.argv,
        )
        standalone.main()
        sys.argv = save


def gen_all_parsers() -> None:
    """Generate all parsers."""
    generate_static_parser(force=True)
    generate_ts_static_parser(force=True)
    print("Parsers generated.")


try:
    from jaclang.compiler.larkparse import jac_parser as jac_lark

    jac_lark.logger.setLevel(logging.DEBUG)
except (ModuleNotFoundError, ImportError):
    print("Parser not present, generating for developer setup...", file=sys.stderr)
    try:
        gen_all_parsers()
        from jaclang.compiler.larkparse import jac_parser as jac_lark

        jac_lark.logger.setLevel(logging.DEBUG)
    except Exception as e:
        print(f"Warning: Could not load parser: {e}", file=sys.stderr)
        jac_lark = None  # type: ignore

TOKEN_MAP = (
    {
        x.name: x.pattern.value
        for x in jac_lark.Lark_StandAlone().parser.lexer_conf.terminals
    }
    if jac_lark
    else {}
)
# fmt: off
TOKEN_MAP.update({
    "CARROW_L": "<++", "CARROW_R": "++>", "GLOBAL_OP": "global", "NONLOCAL_OP": "nonlocal",
    "WALKER_OP": ":walker:", "NODE_OP": ":node:", "EDGE_OP": ":edge:", "CLASS_OP": ":class:",
    "OBJECT_OP": ":obj:", "TYPE_OP": "`", "ABILITY_OP": ":can:", "NULL_OK": "?", "KW_OR": "|",
    "ARROW_BI": "<-->", "ARROW_L": "<--", "ARROW_R": "-->", "ARROW_L_P1": "<-:", "ARROW_R_P2": ":->",
    "ARROW_L_P2": ":<-", "ARROW_R_P1": "->:", "CARROW_BI": "<++>", "CARROW_L_P1": "<+:",
    "RSHIFT_EQ": ">>=", "ELLIPSIS": "...", "CARROW_R_P2": ":+>", "CARROW_L_P2": ":<+",
    "CARROW_R_P1": "+>:", "PIPE_FWD": "|>", "PIPE_BKWD": "<|", "A_PIPE_FWD": ":>", "A_PIPE_BKWD": "<:",
    "DOT_FWD": ".>", "STAR_POW": "**", "STAR_MUL": "*", "FLOOR_DIV": "//", "DIV": "/",
    "PYNLINE": "::py::", "ADD_EQ": "+=", "SUB_EQ": "-=", "STAR_POW_EQ": "**=", "MUL_EQ": "*=",
    "FLOOR_DIV_EQ": "//=", "DIV_EQ": "/=", "MOD_EQ": "%=", "BW_AND_EQ": "&=", "BW_OR_EQ": "|=",
    "BW_XOR_EQ": "^=", "BW_NOT_EQ": "~=", "LSHIFT_EQ": "<<=",
})
# fmt: on

__all__ = [
    "jac_lark",
    "TOKEN_MAP",
    "generate_static_parser",
    "generate_ts_static_parser",
    "gen_all_parsers",
]

if __name__ == "__main__":
    gen_all_parsers()
