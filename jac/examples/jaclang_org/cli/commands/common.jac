import sys;
import from jaclang.server.bridge {
    BridgeError,
    BridgeRejected,
    BridgeTimeout,
    BridgeUnavailable
}

glob EXIT_OK: int = 0,
     EXIT_FAILURE: int = 1,
     EXIT_USAGE: int = 2,
     EXIT_UNAVAILABLE: int = 3,
     EXIT_TIMEOUT: int = 4,
     EXIT_REJECTED: int = 5;

glob START_HINT: str = "hint: start the site with `jac run web`";

def warn(text: str) {
    print(text, file=sys.stderr);
}

def _suffix(detail: str) -> str {
    return " (" + detail + ")" if detail else "";
}

def explain_bridge_error(e: BridgeError) -> int {
    where = e.app + "." + e.name;
    if isinstance(e, BridgeUnavailable) {
        warn("jacorg: " + where + " is not reachable" + _suffix(e.detail));
        warn(START_HINT);
        return EXIT_UNAVAILABLE;
    }
    if isinstance(e, BridgeTimeout) {
        warn("jacorg: " + where + " timed out" + _suffix(e.detail));
        return EXIT_TIMEOUT;
    }
    if isinstance(e, BridgeRejected) {
        warn("jacorg: " + where + " rejected the call" + _suffix(e.detail));
        warn("hint: the site wants a signed-in identity for this command");
        return EXIT_REJECTED;
    }
    warn("jacorg: " + where + " failed" + _suffix(e.detail));
    return EXIT_FAILURE;
}
