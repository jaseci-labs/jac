"""Integration tests for memory hierarchy with testcontainers and jac start."""

import contextlib;
import gc;
import os;
import socket;
import subprocess;
import sys;
import time;
import from pathlib { Path }
import from typing { Any, cast }
import redis;
import requests;
import from pymongo { MongoClient }
import from testcontainers.mongodb { MongoDbContainer }
import from testcontainers.redis { RedisContainer }

def get_free_port -> int {
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s {
        s.bind(("", 0));
        return s.getsockname()[1];
    }
}

glob FIXTURES_DIR = Path(__file__).parent / "fixtures",
     JAC_FILE = FIXTURES_DIR / "todo_app.jac";

"""Extract data from TransportResponse envelope format."""
def extract_transport_response_data(
    json_response: dict[str, Any] | list[Any]
) -> dict[str, Any] | list[Any] {
    if isinstance(json_response, list) {
        if len(json_response) == 2 {
            body: dict[str, Any] = json_response[1];
            json_response = body;
        }
    }

    if (
        isinstance(json_response, dict)
        and "ok" in json_response
        and "data" in json_response
    ) {
        if json_response.get("ok") and json_response.get("data") is not None {
            return json_response["data"];
        } elif not json_response.get("ok") and json_response.get("error") {
            error_info = json_response["error"];
            result: dict[str, Any] = {
                "error": error_info.get("message", "Unknown error")
            };
            if "code" in error_info {
                result["error_code"] = error_info["code"];
            }
            if "details" in error_info {
                result["error_details"] = error_info["details"];
            }
            return result;
        }
    }
    return json_response;
}

def register_user(base_url: str, username: str, password: str = "password123") -> str {
    res = requests.post(
        f"{base_url}/user/register",
        json={"username": username, "password": password},
        timeout=5
    );
    assert res.status_code == 201 , f"Registration failed: {res.status_code} - {res.text}";
    data = cast(dict[str, Any], extract_transport_response_data(res.json()));
    return data["token"];
}

def post_request(base_url: str, path: str, payload: dict, token: str) -> dict[str, Any] {
    res = requests.post(
        f"{base_url}{path}",
        json=payload,
        headers={"Authorization": f"Bearer {token}"},
        timeout=5
    );
    assert res.status_code == 200;
    return cast(dict[str, Any], extract_transport_response_data(res.json()));
}

"""Start jac server and wait for it to become ready."""
def start_server(fixtures_dir: Path, jac_file: Path, port: int) -> subprocess.Popen {
    jac_executable = Path(sys.executable).parent / "jac";
    cmd = [str(jac_executable), "start", str(jac_file.name), "--port", str(port)];

    env = os.environ.copy();

    server = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        cwd=str(fixtures_dir),
        env=env
    );

    base_url = f"http://localhost:{port}";
    for _ in range(30) {
        try {
            r = requests.get(f"{base_url}/docs", timeout=1);
            if r.status_code in (200, 404) {
                return server;
            }
        } except Exception {
            time.sleep(1);
        }
    }

    (stdout, stderr) = server.communicate(timeout=2);
    raise RuntimeError(
        f"jac start failed to start\nSTDOUT:\n{stdout}\nSTDERR:\n{stderr}"
    ) ;
}

test "read and write" {
    if not JAC_FILE.exists() {
        raise FileNotFoundError(f"Missing Jac file: {JAC_FILE}") ;
    }

    # Clean up session file from previous runs
    session_file = FIXTURES_DIR / ".jac" / "data" / "todo_app.session.users.json";
    if session_file.exists() {
        os.remove(session_file);
    }

    # Start Redis container
    redis_container = RedisContainer("redis:latest", port=6379);
    redis_container.start();

    redis_host = redis_container.get_container_host_ip();
    redis_port = redis_container.get_exposed_port(6379);
    redis_url = f"redis://{redis_host}:{redis_port}/0";

    redis_client = redis.Redis(
        host=redis_host, port=int(redis_port), decode_responses=False
    );
    assert redis_client.dbsize() == 0;

    # Start Mongo container
    mongo_container = MongoDbContainer("mongo:latest");
    mongo_container.start();

    mongo_uri = mongo_container.get_connection_url();
    mongo_client = MongoClient(mongo_uri);

    os.environ["MONGODB_URI"] = mongo_uri;
    os.environ["REDIS_URL"] = redis_url;

    assert "jac_db" not in mongo_client.list_database_names();

    port = get_free_port();
    base_url = f"http://localhost:{port}";

    server = start_server(FIXTURES_DIR, JAC_FILE, port);

    try {
        db = mongo_client["jac_db"];
        collection = db["anchors"];

        mongo_doc_initial_count = collection.count_documents({});
        assert mongo_doc_initial_count == 2 , (
            "Initial docs should be 2 (super root, guest_user)"
        );

        # Register a user
        token = register_user(base_url, "reader", "pass123");

        mongo_doc_after_user_creation_count = collection.count_documents({});
        assert mongo_doc_after_user_creation_count == 3 , (
            "After user creation docs should be 3 (super root, guest_user, created user)"
        );

        redis_size_before_task_creation = redis_client.dbsize();

        # Create tasks
        created_tasks = [
            {"id": 203, "title": "Task 203"},
            {"id": 204, "title": "Task 204"}
        ];

        redis_size_after_task_creation = redis_client.dbsize();

        for task_payload in created_tasks {
            post_request(base_url, "/walker/CreateTask", task_payload, token);
        }

        mongo_doc_count_after_task_creation = collection.count_documents({});
        assert mongo_doc_count_after_task_creation == 7 , (
            "After task creation docs should be 7 (prev 3 + 2 anchors per task)"
        );

        assert redis_size_after_task_creation == redis_size_before_task_creation;

        post_request(base_url, "/walker/GetAllTasks", {}, token);

        redis_size_after_task_read = redis_client.dbsize();
        assert redis_size_after_task_read == 7 , (
            "Redis should have 7 entries (super root, guest user, user, 2 task nodes, 2 edges)"
        );
    } finally {
        # Teardown
        if server {
            server.terminate();
            with contextlib.suppress(Exception) {
                server.wait(timeout=5);
            }
        }

        system_dbs = {"admin","config","local"};
        for db_name in mongo_client.list_database_names() {
            if db_name not in system_dbs {
                mongo_client.drop_database(db_name);
            }
        }

        mongo_container.stop();
        redis_container.stop();

        time.sleep(0.5);
        gc.collect();

        session_file = FIXTURES_DIR / ".jac" / "data" / "todo_app.session.users.json";
        if session_file.exists() {
            os.remove(session_file);
        }
    }
}
