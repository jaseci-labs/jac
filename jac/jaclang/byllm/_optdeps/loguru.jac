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
