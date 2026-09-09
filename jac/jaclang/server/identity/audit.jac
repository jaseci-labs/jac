import logging;
import from datetime { UTC, datetime }
import from jaclang.server.serving.datatypes { Request }

glob _audit_logger = logging.getLogger('jaclang.server.identity.audit');


def client_ip(request: Request) -> str {
    return request.client_host or 'unknown';
}

def emit(event: str, **fields: any) {
    payload: dict[str, any] = {
        'event': event,
        'timestamp': datetime.now(UTC).isoformat()
    };
    payload.update(fields);
    _audit_logger.info(event, extra={'audit': payload});
}
