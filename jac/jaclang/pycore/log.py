"""Basic Logging Module for Jac Compiler."""

import logging

logging.basicConfig(
    # level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
    level=logging.INFO,
    format="%(levelname)s - %(message)s",
)

__all__ = ["logging"]
