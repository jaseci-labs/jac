import json;


def serialize_response(resp: any) -> str;


def replay_response(cached: str) -> any;


obj BridgeError(RuntimeError) {
    has app: str = "",
        name: str = "",
        detail: str = "",
        status: int = 0;

    def __str__ -> str;
}

obj BridgeUnavailable(BridgeError) {}

obj BridgeTimeout(BridgeError) {}

obj BridgeRejected(BridgeError) {}


def bridge_error_for_status(
    status: int, app: str, name: str, detail: str
) -> BridgeError;


def bridge_error_from(exc: Exception, app: str, name: str) -> BridgeError;
