import logging;
import from datetime { UTC, datetime }

glob _audit_logger = logging.getLogger('jaclang.scale.identity.audit');

def emit(event: str, **fields: any) {
    payload: dict[str, any] = {
        'event': event,
        'timestamp': datetime.now(UTC).isoformat()
    };
    payload.update(fields);
    _audit_logger.info(event, extra={'audit': payload});
}
