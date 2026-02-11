"""Basic Logging Module for Jac Compiler."""
import logging;

with entry {
    logging.basicConfig(level=logging.INFO, format="%(levelname)s - %(message)s");
}

glob __all__ = ["logging"];
