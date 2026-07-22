import logging;
import re;
import from jaclang.scale._optdeps.pymongo { HAS_PYMONGO }

glob logger = logging.getLogger(__name__);


def redact_mongo_uri(uri: (str | None)) -> str {
    return re.sub(r"://[^/@]*@", "://***@", str(uri or ""));
}


def mongo_reachable(client: (any | None)) -> bool {
    if not HAS_PYMONGO or client is None {
        return False;
    }
    try {
        client.admin.command('ping');
        return True;
    } except Exception as e {
        logger.debug(f"MongoDB ping failed: {e}");
        return False;
    }
}


def warn_mongo_unreachable(uri: (str | None), timeout_ms: int, fallback: str) {
    logger.warning(
        "cannot reach MongoDB at " + redact_mongo_uri(uri) + f"; falling back to {fallback}. Set MONGODB_TIMEOUT_MS to change the " + f"{timeout_ms}ms probe budget, or unset MONGODB_URI to skip Mongo entirely."
    );
}
