import logging;
import from datetime { UTC, datetime }

glob _audit_logger = logging.getLogger('jaclang.server.identity.audit');


def client_ip(request: Request) -> str;

def emit(event: str, **fields: any);
