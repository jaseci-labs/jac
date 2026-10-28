import json;
import logging;
import sys;
import time;
import from urllib.parse { unquote_plus }

glob ACCESS_LOGGER_NAME: str = 'jaclang.serving.access',
     access_logger: logging.Logger = logging.getLogger(ACCESS_LOGGER_NAME),
     CREDENTIAL_QUERY_KEYS: set[str] = {'token', 'access_token', 'api_key'},
     REDACTED_QUERY_VALUE: str = '[REDACTED]';


def _scrub_query(query: str) -> str;


obj AccessRecord {
    has client: str = '-',
        method: str = '',
        path: str = '',
        query: str = '',
        version: str = 'HTTP/1.1',
        status: int = 0,
        bytes_sent: int = 0,
        duration_ms: float = 0.0,
        request_id: str = '',
        user_agent: str = '',
        referer: str = '',
        scheme: str = 'http',
        ts: float = 0.0;

    def postinit;
    def as_dict -> dict[str, any];
    def as_text -> str;
}


def emit(record: AccessRecord);


class AccessTextFormatter(logging.Formatter) {
    def format(self: AccessTextFormatter, record: logging.LogRecord) -> str;
}

class AccessJsonFormatter(logging.Formatter) {
    def format(self: AccessJsonFormatter, record: logging.LogRecord) -> str;
}

class HealthCheckFilter(logging.Filter) {
    def filter(self: HealthCheckFilter, record: logging.LogRecord) -> bool;
}


def configure_access_logging(
    enabled: bool = True, format: str = 'text', suppress_health_checks: bool = False
);
