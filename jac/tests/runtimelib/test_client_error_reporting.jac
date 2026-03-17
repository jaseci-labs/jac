"""Tests for client-side error reporting endpoint.

The /cl/__error__ endpoint allows client-side JavaScript to report
errors back to the server for logging and observability.
"""

import io;
import json;
import logging;
import uuid;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.runtimelib.testing { JacTestClient }

glob FIXTURES = str(Path(__file__).parent / "fixtures");

def fixture_abs_path(filename: str) -> str {
    return str((Path(FIXTURES) / filename).resolve());
}

def make_client(base_path: str) -> JacTestClient {
    return JacTestClient.from_file(
        fixture_abs_path("serve_api.jac"), base_path=base_path
    );
}

"""Attach a StringIO handler to logger and return (buf, handler, old_level)."""
def capture_log_start(logger: logging.Logger, level: int = logging.DEBUG) -> tuple {
    buf = io.StringIO();
    handler = logging.StreamHandler(buf);
    handler.setLevel(level);
    logger.addHandler(handler);
    old_level = logger.level;
    logger.setLevel(level);
    return (buf, handler, old_level);
}

"""Remove handler and restore logger level."""
def capture_log_stop(
    logger: logging.Logger, handler: logging.StreamHandler, old_level: int
) -> None {
    logger.removeHandler(handler);
    logger.setLevel(old_level);
}

# =============================================================================
# Client Error Reporting Tests
# =============================================================================
test "client error endpoint exists and accepts error reports" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        response = client.post(
            "/cl/__error__",
            json={
                "message": "Cannot use 'in' operator to search for '@' in undefined",
                "stack": "TypeError: Cannot use 'in' operator\n    at LoginPage (login.jac:42)",
                "url": "http://localhost:8001/",
                "source": "window.onerror",
                "timestamp": "2026-03-14T12:00:00Z"
            }
        );
        assert response.status_code == 200;
        client.close();
    }
}

test "client error is logged to server console" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        logger = logging.getLogger("jaclang.client_errors");
        (buf, handler, old_level) = capture_log_start(logger);
        try {
            # Use unique message to avoid rate limiter dedup across test runs
            error_msg = f"Test error {uuid.uuid4().hex}";
            client.post(
                "/cl/__error__",
                json={
                    "message": error_msg,
                    "stack": "TypeError: test\n    at TestFunc (test.jac:1)",
                    "url": "http://localhost:8001/",
                    "source": "window.onerror",
                    "timestamp": "2026-03-14T12:00:00Z"
                }
            );
            log_output = buf.getvalue();
            assert error_msg in log_output , f"Expected client error in log output, got: {log_output}";
        } finally {
            capture_log_stop(logger, handler, old_level);
        }
        client.close();
    }
}

test "client error endpoint handles missing fields gracefully" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        # Minimal payload - just a message
        response = client.post("/cl/__error__", json={"message": "Something broke"});
        assert response.status_code == 200;
        client.close();
    }
}

test "client error endpoint rejects empty payload" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        response = client.post("/cl/__error__", json={});
        assert response.status_code == 400;
        client.close();
    }
}
