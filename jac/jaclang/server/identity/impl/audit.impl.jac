impl client_ip(request: Request) -> str {
    return request.client_host or 'unknown';
}

impl emit(event: str, **fields: any) {
    payload: dict[str, any] = {
        'event': event,
        'timestamp': datetime.now(UTC).isoformat()
    };
    payload.update(fields);
    _audit_logger.info(event, extra={'audit': payload});
}
