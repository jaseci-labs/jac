impl _scrub_query(query: str) -> str {
    if not query {
        return query;
    }
    scrubbed: list[str] = [];
    for component in query.split('&') {
        key = component.split('=', 1)[0];
        if unquote_plus(key).lower() in CREDENTIAL_QUERY_KEYS {
            scrubbed.append(f"{key}={REDACTED_QUERY_VALUE}");
        } else {
            scrubbed.append(component);
        }
    }
    return '&'.join(scrubbed);
}

impl AccessRecord.postinit {
    self.query = _scrub_query(self.query);
}

impl AccessRecord.as_dict -> dict[str, any] {
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

impl AccessRecord.as_text -> str {
    target = self.path + (f"?{self.query}" if self.query else '');
    return (
        f'{self.client} "{self.method} {target} {self.version}" {self.status} '
        f'{self.bytes_sent} {self.duration_ms:.1f}ms {self.request_id}'
    );
}

impl emit(record: AccessRecord) {
    if access_logger.isEnabledFor(logging.INFO) {
        access_logger.info(record.as_text(), extra={'access': record});
    }
}

impl AccessTextFormatter.format(
    self: AccessTextFormatter, record: logging.LogRecord
) -> str {
    return record.getMessage();
}

impl AccessJsonFormatter.format(
    self: AccessJsonFormatter, record: logging.LogRecord
) -> str {
    payload = record?.access;
    if isinstance(payload, AccessRecord) {
        return json.dumps(payload.as_dict(), separators=(',', ':'));
    }
    return json.dumps({'msg': record.getMessage()});
}

impl HealthCheckFilter.filter(
    self: HealthCheckFilter, record: logging.LogRecord
) -> bool {
    payload = record?.access;
    if isinstance(payload, AccessRecord) {
        return payload.path not in HEALTH_PATHS;
    }
    return True;
}

impl configure_access_logging(
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
