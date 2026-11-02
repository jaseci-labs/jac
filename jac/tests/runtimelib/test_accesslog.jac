import json;
import logging;
import from jaclang.server.serving.accesslog {
    ACCESS_LOGGER_NAME,
    AccessJsonFormatter,
    AccessRecord
}

test "access log redacts credential query values for text and json" {
    query = (
        "room=ops&label=hello%20world&token=first-secret&token=second-secret"
        "&ACCESS_TOKEN=third-secret"
        "&%61%70%69%5f%6b%65%79=fourth-secret"
        "&%74oken=%66ifth-secret"
    );
    access = AccessRecord(
        client='127.0.0.1', method='GET', path='/ws/Chat', query=query, status=101
    );
    text = access.as_text();
    record = logging.LogRecord(
        name=ACCESS_LOGGER_NAME,
        level=logging.INFO,
        pathname="",
        lineno=0,
        msg=text,
        args=(),
        exc_info=None
    );
    setattr(record, 'access', access);
    json_text = AccessJsonFormatter().format(record);
    payload = json.loads(json_text);

    for secret in [
        'first-secret',
        'second-secret',
        'third-secret',
        'fourth-secret',
        'fifth-secret'
    ] {
        assert secret not in access.query , f"record leaked {secret}";
        assert secret not in text , f"text log leaked {secret}";
        assert secret not in json_text , f"json log leaked {secret}";
    }
    assert 'room=ops' in access.query , "benign query data was lost";
    assert 'label=hello%20world' in access.query , "benign encoding was changed";
    assert payload['status'] == 101;
    assert payload['query'].count('[REDACTED]') == 5;
}
