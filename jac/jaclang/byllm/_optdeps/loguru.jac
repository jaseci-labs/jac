"""Guarded `logger` for byllm (capability: llm).

loguru is byllm's runtime logger and ships with the `llm` capability. To keep the
byllm public API importable without that capability installed, fall back to a
stdlib logger when loguru is absent. Runtime code only uses the shared methods
(error/info/debug/warning/exception); loguru-specific sink APIs (add/remove) are
exercised only by tests, which always run with the `llm` capability present.
"""

import logging;

with entry {
    try {
        import from loguru { logger }
        HAS_LOGURU = True;
    } except ImportError {
        logger = logging.getLogger("jaclang.byllm");
        HAS_LOGURU = False;
    }
}
