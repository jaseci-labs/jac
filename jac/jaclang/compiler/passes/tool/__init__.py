"""Collection of passes for Jac IR."""

from .comment_injection_pass import CommentInjectionPass
from .doc_ir_gen_pass import DocIRGenPass
from .jac_formatter_pass import JacFormatPass

__all__ = [
    "CommentInjectionPass",
    "DocIRGenPass",
    "JacFormatPass",
]
