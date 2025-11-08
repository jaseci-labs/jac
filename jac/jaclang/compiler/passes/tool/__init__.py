"""Collection of passes for Jac IR."""

from .fuse_comments_pass import FuseCommentsPass  # noqa: I100
from .jac_formatter_pass import JacFormatPass  # noqa: I100
from .doc_ir_gen_pass import DocIRGenPass  # noqa: I100

__all__ = [
    "DocIRGenPass",
    "FuseCommentsPass",
    "JacFormatPass",
]
