import json;
import logging;
import sys;
import time;
import from jaclang.server.serving.drain { HEALTH_PATHS }

glob ACCESS_LOGGER_NAME: str = 'jaclang.serving.access',
     access_logger: logging.Logger = logging.getLogger(ACCESS_LOGGER_NAME);


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

    def as_dict -> dict[str, any] {
        return {
            'ts': time.strftime('%Y-%m-%dT%H:%M:%S', time.gmtime(self.ts))
                + f".{int((self.ts % 1) * 1000):03d}Z",
            'client': self.client,
            'method': self.method,
            'path': self.path,
            'query': self.query,
            'version': self.version,
            'scheme': self.scheme,
            'status': self.status,
            'bytes': self.bytes_sent,
            'duration_ms': round(self.duration_ms, 3),
            'request_id': self.request_id,
            'user_agent': self.user_agent,
            'referer': self.referer
        };
    }

    def as_text -> str {
        target = self.path + (f"?{self.query}" if self.query else '');
        return (
            f'{self.client} "{self.method} {target} {self.version}" {self.status} '
            f'{self.bytes_sent} {self.duration_ms:.1f}ms {self.request_id}'
        );
    }
}


def emit(record: AccessRecord) {
    if access_logger.isEnabledFor(logging.INFO) {
        access_logger.info(record.as_text(), extra={'access': record});
    }
}


class AccessTextFormatter(logging.Formatter) {
    def format(self: AccessTextFormatter, record: logging.LogRecord) -> str {
        return record.getMessage();
    }
}

class AccessJsonFormatter(logging.Formatter) {
    def format(self: AccessJsonFormatter, record: logging.LogRecord) -> str {
        payload = record?.access;
        if isinstance(payload, AccessRecord) {
            return json.dumps(payload.as_dict(), separators=(',', ':'));
        }
        return json.dumps({'msg': record.getMessage()});
    }
}

class HealthCheckFilter(logging.Filter) {
    def filter(self: HealthCheckFilter, record: logging.LogRecord) -> bool {
        payload = record?.access;
        if isinstance(payload, AccessRecord) {
            return payload.path not in HEALTH_PATHS;
        }
        return True;
    }
}


def configure_access_logging(
    enabled: bool = True, format: str = 'text', suppress_health_checks: bool = False
) {
    for old in list(access_logger.handlers) {
        access_logger.removeHandler(old);
    }
    access_logger.propagate = False;
    if not enabled {
        access_logger.addHandler(logging.NullHandler());
        access_logger.setLevel(int(logging.CRITICAL));
        return;
    }
    handler = logging.StreamHandler(sys.stdout);
    handler.setFormatter(
        AccessJsonFormatter() if format == 'json' else AccessTextFormatter()
    );
    if suppress_health_checks {
        handler.addFilter(HealthCheckFilter());
    }
    access_logger.addHandler(handler);
    access_logger.setLevel(int(logging.INFO));
}
