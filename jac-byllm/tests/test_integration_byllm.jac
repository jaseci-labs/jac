"""Integration tests for byllm multi-agent application.

This test suite validates:
- jac start command works properly
- Server starts and accepts connections
- Walker HTTP endpoints are accessible
- Supervisor routing works correctly
- Agent responses are correct
"""

import gc;
import json;
import os;
import shutil;
import socket;
import sys;
import time;
import pytest;

import from subprocess { Popen }
import from urllib.error { HTTPError }
import from urllib.request { Request, urlopen }


"""Get a free port by binding to port 0 and releasing it."""
def get_free_port -> int {
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s {
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1);
        s.bind(("", 0));
        s.listen(1);
        port = s.getsockname()[1];
    }
    return port;
}

"""Get the jac command with proper path handling."""
def get_jac_command -> list[str] {
    jac_path = shutil.which("jac");
    if jac_path {
        return [jac_path];
    }
    return [sys.executable, "-m", "jaclang"];
}

"""Block until a TCP port is accepting connections or timeout."""
def wait_for_port(host: str, port: int, timeout: float = 60.0) -> None {
    deadline = time.time() + timeout;
    while time.time() < deadline {
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock {
            sock.settimeout(0.5);
            try {
                sock.connect((host, port));
                return;
            } except OSError {
                time.sleep(0.5);
            }
        }
    }
    raise TimeoutError(f"Timed out waiting for {host}:{port}");
}

"""Register a test user and return the auth token."""
def register_user(port: int) -> str {
    payload = {"username": "test_user", "password": "test_password"};
    req = Request(
        f"http://127.0.0.1:{port}/user/register",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
        method="POST"
    );
    try {
        with urlopen(req, timeout=30) as resp {
            body = json.loads(resp.read().decode());
            if "data" in body {
                return body["data"]["token"];
            }
            return body["token"];
        }
    } except HTTPError as exc {
        # If user already exists (400), try logging in instead
        if exc.code == 400 {
            login_payload = {"username": "test_user", "password": "test_password"};
            login_req = Request(
                f"http://127.0.0.1:{port}/user/login",
                data=json.dumps(login_payload).encode(),
                headers={"Content-Type": "application/json"},
                method="POST"
            );
            with urlopen(login_req, timeout=30) as resp {
                body = json.loads(resp.read().decode());
                if "data" in body {
                    return body["data"]["token"];
                }
                return body["token"];
            }
        }
        raise;
    }
}

"""Make a POST request with JSON payload and return parsed response."""
def post_json(port: int, path: str, payload: dict, token: str = "") -> dict {
    headers = {"Content-Type": "application/json"};
    if token {
        headers["Authorization"] = f"Bearer {token}";
    }
    req = Request(
        f"http://127.0.0.1:{port}{path}",
        data=json.dumps(payload).encode(),
        headers=headers,
        method="POST"
    );
    with urlopen(req, timeout=90) as resp {
        assert resp.status == 200 , f"Expected 200, got {resp.status}";
        body = json.loads(resp.read().decode());
        # Unwrap TransportResponse envelope if present
        if isinstance(body, dict) and "data" in body and "ok" in body {
            return body["data"];
        }
        return body;
    }
}

# ---------------------------------------------------------------------------
# Module-level shared server state — started once for all tests
# ---------------------------------------------------------------------------
glob _server: object = None,
     _server_port: int = 0,
     _server_token: str = "";

"""Start the shared byllm server (called once before all tests)."""
def setup_byllm_server -> None {
    global _server,_server_port,_server_token;
    tests_dir = os.path.dirname(os.path.abspath(__file__));
    fixture_path = os.path.join(tests_dir, "fixtures", "integration_byllm");
    _server_port = get_free_port();
    jac_cmd = get_jac_command();

    _server = Popen(
        [*jac_cmd, "start", "main.jac", "-p", str(_server_port)], cwd=fixture_path
    );
    wait_for_port("127.0.0.1", _server_port, timeout=60.0);
    _server_token = register_user(_server_port);
}

"""Tear down the shared byllm server (called once after all tests)."""
def teardown_byllm_server -> None {
    global _server;
    if _server is not None {
        _server.terminate();
        try {
            _server.wait(timeout=15);
        } except Exception {
            _server.kill();
            _server.wait(timeout=5);
        }
        _server = None;
        time.sleep(1);
        gc.collect();
    }
}

# ---------------------------------------------------------------------------
# Server start test
# ---------------------------------------------------------------------------
test "server starts successfully" {
    setup_byllm_server();
    # Verify server process is still alive
    assert _server.poll() is None , "Server should be running";

    # Verify port is still accepting connections
    try {
        wait_for_port("127.0.0.1", _server_port, timeout=5.0);
    } except TimeoutError {
        teardown_byllm_server();
        pytest.fail("Server port is not accepting connections");
    }
}


# ---------------------------------------------------------------------------
# Walker endpoint tests
# ---------------------------------------------------------------------------
test "supervisor routes to concept agent" {
    concept_payload = {"query": "Explain machine learning in simple terms"};

    try {
        response_data = post_json(
            _server_port, "/walker/Supervisor", concept_payload, _server_token
        );

        if "reports" in response_data {
            reports = response_data["reports"];
            assert len(reports) > 0 , "Should have at least one report";
            agent_report = reports[0];
            assert agent_report["agent"] == "ConceptAgent" , f"Expected ConceptAgent, got {agent_report.get(
                'agent'
            )}";
            assert len(agent_report["response"]) > 0 , "Response should not be empty";
        } else {
            assert len(response_data) > 0 , "Response should not be empty";
        }
    } except HTTPError as exc {
        error_body = exc.read().decode("utf-8", errors="ignore") if exc.fp else "";
        pytest.fail(f"ConceptAgent test failed: {exc.code}\n{error_body}");
    }
}

test "supervisor routes to math agent with streaming" {
    math_payload = {"query": "What is (15 + 5) * 2 - (10 / 2)?"};

    try {
        response_data = post_json(
            _server_port, "/walker/Supervisor", math_payload, _server_token
        );

        if "reports" in response_data {
            reports = response_data["reports"];
            assert len(reports) > 0 , "Should have at least one report";
            agent_report = reports[0];
            assert agent_report["agent"] == "MathAgent" , f"Expected MathAgent, got {agent_report.get(
                'agent'
            )}";
            assert len(agent_report["response"]) > 0 , "Response should not be empty";
            # MathAgent uses stream=True, logging=True — the handler
            # iterates StreamEvent objects from the ReAct pipeline
            # (tool_call → tool_result → steps_done → chunk).
            # A correct "35.0" proves the full streaming chain worked.
            assert "35" in agent_report["response"] , f"Expected 35 in streamed response, got {agent_report[
                'response'
            ]}";
        } else {
            assert len(response_data) > 0 , "Response should not be empty";
        }
    } except HTTPError as exc {
        error_body = exc.read().decode("utf-8", errors="ignore") if exc.fp else "";
        pytest.fail(f"MathAgent streaming test failed: {exc.code}\n{error_body}");
    }
}

test "supervisor routes to code agent with streaming" {
    code_payload = {
        "query": "Write a Python function to compute the Fibonacci sequence"
    };

    try {
        response_data = post_json(
            _server_port, "/walker/Supervisor", code_payload, _server_token
        );

        if "reports" in response_data {
            reports = response_data["reports"];
            assert len(reports) > 0 , "Should have at least one report";
            agent_report = reports[0];
            assert agent_report["agent"] == "CodeAgent" , f"Expected CodeAgent, got {agent_report.get(
                'agent'
            )}";
            assert len(agent_report["response"]) > 0 , "Response should not be empty";
            # CodeAgent uses stream=True, logging=True with ReAct pipeline.
            # A correct response containing 'fibonacci' proves the full streaming chain worked.
            assert "fibonacci" in agent_report["response"].lower() , f"Expected fibonacci in streamed response, got {agent_report[
                'response'
            ]}";
        } else {
            assert len(response_data) > 0 , "Response should not be empty";
        }
    } except HTTPError as exc {
        error_body = exc.read().decode("utf-8", errors="ignore") if exc.fp else "";
        pytest.fail(f"CodeAgent streaming test failed: {exc.code}\n{error_body}");
    }
}

test "supervisor routes to research agent" {
    research_payload = {
        "query": "Compare supervised fine-tuning and prompt engineering in large language models"
    };

    try {
        response_data = post_json(
            _server_port, "/walker/Supervisor", research_payload, _server_token
        );

        if "reports" in response_data {
            reports = response_data["reports"];
            assert len(reports) > 0 , "Should have at least one report";
            agent_report = reports[0];
            assert agent_report["agent"] == "ResearchAgent" , f"Expected ResearchAgent, got {agent_report.get(
                'agent'
            )}";
            assert "summary" in agent_report , "Should have summary field";
            assert len(agent_report["summary"]) > 0 , "Summary should not be empty";
        } else {
            assert len(response_data) > 0 , "Response should not be empty";
        }
    } except HTTPError as exc {
        error_body = exc.read().decode("utf-8", errors="ignore") if exc.fp else "";
        pytest.fail(f"ResearchAgent test failed: {exc.code}\n{error_body}");
    }
    teardown_byllm_server();
}
