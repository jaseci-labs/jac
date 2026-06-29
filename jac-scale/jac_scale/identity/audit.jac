import logging;
import from datetime { UTC, datetime }
import from typing { Any }
import from jac_scale.runtime.middleware.rate_limit { _resolve_client_ip as client_ip }

glob _audit_logger = logging.getLogger('jac_scale.identity.audit');

def emit(event: str, **fields: Any) {
    payload: dict[str, Any] = {
        'event': event,
        'timestamp': datetime.now(UTC).isoformat()
    };
    payload.update(fields);
    _audit_logger.info(event, extra={'audit': payload});
}
