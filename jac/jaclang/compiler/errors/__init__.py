"""Centralized error system for Jac compiler."""

from jaclang.compiler.errors.error_codes import JacErrorCode
from jaclang.compiler.errors.error_messages import (
    ERROR_MESSAGE_TEMPLATES,
    get_error_message,
)
from jaclang.compiler.errors.error_params import *  # noqa: F401, F403, I202

__all__ = [
    "JacErrorCode",
    "ERROR_MESSAGE_TEMPLATES",
    "get_error_message",
    # Error parameter types are exported via __all__ from error_params
]
