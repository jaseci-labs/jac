"""Integration tests for memory hierarchy with testcontainers and jac start."""

import atexit;
import contextlib;
import concurrent.futures;
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
import from jac_scale.context { JScaleExecutionContext }
import from jac_scale.memory_hierarchy { _process_cache, MongoBackend }
import from jac_scale.db { close_all_db_connections }

def get_free_port -> int {
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s {
        s.bind(("", 0));
        return s.getsockname()[1];
    }
}

glob FIXTURES_DIR = Path(__file__).parent / "fixtures",
     JAC_FILE = FIXTURES_DIR / "todo_app.jac",
     _shared: dict = {};

"""Lazily start a shared MongoDB container; return (MongoClient, uri)."""
def _get_mongo -> tuple {
    if "mongo_client" not in _shared {
        c = MongoDbContainer("mongo:latest");
        c.start();
        uri = c.get_connection_url();
        _shared["mongo_container"] = c;
        _shared["mongo_uri"] = uri;
        _shared["mongo_client"] = MongoClient(uri);
        atexit.register(c.stop);
    }
    return (_shared["mongo_client"], _shared["mongo_uri"]);
}

"""Lazily start a shared Redis container; return (redis.Redis, url)."""
def _get_redis -> tuple {
    if "redis_client" not in _shared {
        c = RedisContainer("redis:latest", port=6379);
        c.start();
        host = c.get_container_host_ip();
        exposed_port = c.get_exposed_port(6379);
        url = f"redis://{host}:{exposed_port}/0";
        _shared["redis_container"] = c;
        _shared["redis_url"] = url;
        _shared["redis_client"] = redis.Redis(
            host=host, port=int(exposed_port), decode_responses=False
        );
        atexit.register(c.stop);
    }
    return (_shared["redis_client"], _shared["redis_url"]);
}

"""Drop all non-system databases (resets jac_db between tests)."""
def _reset_mongo -> None {
    if "mongo_client" not in _shared {
        return;
    }
    system_dbs = {"admin","config","local"};
    for db_name in _shared["mongo_client"].list_database_names() {
        if db_name not in system_dbs {
            _shared["mongo_client"].drop_database(db_name);
        }
    }
}

"""Flush all Redis keys (resets state between tests)."""
def _reset_redis {
    if "redis_client" in _shared {
        _shared["redis_client"].flushall();
    }
}

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
        json={
            "identities": [{"type": "username", "value": username}],
            "credential": {"type": "password", "password": password}
        },
        timeout=2
    );
    assert res.status_code == 201 , f"Registration failed: {res.status_code} - {res.text}";
    login_res = requests.post(
        f"{base_url}/user/login",
        json={
            "identity": {"type": "username", "value": username},
            "credential": {"type": "password", "password": password}
        },
        timeout=2
    );
    assert login_res.status_code == 200 , f"Login failed: {login_res.status_code} - {login_res.text}";
    login_data = cast(
        dict[str, Any], extract_transport_response_data(login_res.json())
    );
    return login_data["token"];
}

def post_request(
    base_url: str, path: str, payload: dict, token: str
) -> dict[str, Any] {
    res = requests.post(
        f"{base_url}{path}",
        json=payload,
        headers={"Authorization": f"Bearer {token}"},
        timeout=2
    );
    assert res.status_code == 200 , f"POST {path} failed: {res.status_code} - {res.text}";
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
            r = requests.get(f"{base_url}/healthz", timeout=1);
            if r.status_code == 200 {
                return server;
            }
        } except Exception {
            time.sleep(1);
        }
    }

    (stdout, stderr) = server.communicate(timeout=2);
    raise RuntimeError(
        f"jac start failed to start\nSTDOUT:\n{stdout}\nSTDERR:\n{stderr}"
    );
}

test "read and write" {
    if not JAC_FILE.exists() {
        raise FileNotFoundError(f"Missing Jac file: {JAC_FILE}");
    }

    # Clean up data files from previous runs
    data_dir = FIXTURES_DIR / ".jac" / "data";
    if data_dir.exists() {
        import shutil;
        shutil.rmtree(data_dir);
    }

    _reset_mongo();
    _reset_redis();
    (mongo_client, mongo_uri) = _get_mongo();
    (redis_client, redis_url) = _get_redis();
    os.environ["MONGODB_URI"] = mongo_uri;
    os.environ["REDIS_URL"] = redis_url;

    assert redis_client.dbsize() == 0;
    assert "jac_db" not in mongo_client.list_database_names();

    port = get_free_port();
    base_url = f"http://localhost:{port}";

    server = start_server(FIXTURES_DIR, JAC_FILE, port);

    try {
        db = mongo_client["jac_db"];
        collection = db["_anchors"];

        mongo_doc_initial_count = collection.count_documents({});
        assert mongo_doc_initial_count == 4 , (
            "Initial docs should be 4 (super root, guest_user, admin, __system__)"
        );

        # Register a user
        token = register_user(base_url, "reader", "pass123");

        mongo_doc_after_user_creation_count = collection.count_documents({});
        assert mongo_doc_after_user_creation_count == 5 , (
            "After user creation docs should be 5 (super root, guest_user, admin, __system__, created user)"
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
        assert mongo_doc_count_after_task_creation == 9 , (
            "After task creation docs should be 9 (prev 5 + 2 anchors per task)"
        );

        assert redis_size_after_task_creation == redis_size_before_task_creation;

        post_request(base_url, "/walker/GetAllTasks", {}, token);

        redis_size_after_task_read = redis_client.dbsize();
        assert redis_size_after_task_read == 9 , (
            "Redis should have 9 entries (super root, guest user, admin, __system__, user, 2 task nodes, 2 edges)"
        );
    } finally {
        if server {
            server.terminate();
            with contextlib.suppress(Exception) {
                server.wait(timeout=2);
            }
        }

        # Clean up data files
        if data_dir.exists() {
            import shutil;
            shutil.rmtree(data_dir);
        }
    }
}

test "data persists after server restart for mongo db" {
    if not JAC_FILE.exists() {
        raise FileNotFoundError(f"Missing Jac file: {JAC_FILE}");
    }

    # Clean up data files
    data_dir = FIXTURES_DIR / ".jac" / "data";
    if data_dir.exists() {
        import shutil;
        shutil.rmtree(data_dir);
    }

    _reset_mongo();
    (_, mongo_uri) = _get_mongo();
    os.environ["MONGODB_URI"] = mongo_uri;
    if "REDIS_URL" in os.environ {
        del os.environ["REDIS_URL"];
    }

    port = get_free_port();
    base_url = f"http://localhost:{port}";
    server = start_server(FIXTURES_DIR, JAC_FILE, port);

    try {
        # Create task
        res = requests.post(
            f"{base_url}/walker/CreateTask",
            json={"id": 100, "title": "Test persistence"},
            timeout=2
        );
        assert res.status_code == 200;

        # Verify task exists before restart
        res = requests.post(f"{base_url}/walker/GetAllTasks", json={}, timeout=5);
        response_data = cast(
            dict[str, Any], extract_transport_response_data(res.json())
        );
        tasks_before = response_data["reports"][0];
        assert len(tasks_before) == 1 , "Should have 1 task before restart";
        assert tasks_before[0]["id"] == 100 , f"Task id should be 100, got {tasks_before[
            0
        ]['id']}";
        assert tasks_before[0]["title"] == "Test persistence" , f"Task title mismatch: {tasks_before[
            0
        ]['title']}";

        # Restart server
        server.terminate();
        server.wait(timeout=2);
        server = start_server(FIXTURES_DIR, JAC_FILE, port);

        # Verify task persists after restart
        res = requests.post(f"{base_url}/walker/GetAllTasks", json={}, timeout=2);
        response_data = cast(
            dict[str, Any], extract_transport_response_data(res.json())
        );
        tasks_after = response_data["reports"][0];
        assert len(tasks_after) == 1 , "Task should persist after restart";
        assert tasks_after[0]["id"] == 100 , f"Task id should be 100 after restart, got {tasks_after[
            0
        ]['id']}";
        assert tasks_after[0]["title"] == "Test persistence" , f"Task title mismatch after restart: {tasks_after[
            0
        ]['title']}";
    } finally {
        if server {
            server.terminate();
            with contextlib.suppress(Exception) {
                server.wait(timeout=2);
            }
        }
        if data_dir.exists() {
            import shutil;
            shutil.rmtree(data_dir);
        }
    }
}

test "no unnecessary saves on read-only operations" {
    if not JAC_FILE.exists() {
        raise FileNotFoundError(f"Missing Jac file: {JAC_FILE}");
    }

    # Clean up data files
    data_dir = FIXTURES_DIR / ".jac" / "data";
    if data_dir.exists() {
        import shutil;
        shutil.rmtree(data_dir);
    }

    _reset_mongo();
    _reset_redis();
    (mongo_client, mongo_uri) = _get_mongo();
    (_, redis_url) = _get_redis();
    os.environ["MONGODB_URI"] = mongo_uri;
    os.environ["REDIS_URL"] = redis_url;

    port = get_free_port();
    base_url = f"http://localhost:{port}";
    server = start_server(FIXTURES_DIR, JAC_FILE, port);

    def get_update_count -> int {
        server_status = mongo_client.admin.command("serverStatus");
        return server_status["opcounters"]["update"];
    }

    try {
        db = mongo_client["jac_db"];
        collection = db["_anchors"];

        # Initial count after server start
        initial_count = collection.count_documents({});
        assert initial_count == 4 , (f"Initial count should be 4, got {initial_count}");

        # Make a read-only request (walker with no data changes)
        token = register_user(base_url, "readonly_user", "pass123");

        # Count after user creation
        after_user_count = collection.count_documents({});
        assert after_user_count == 5 , (
            f"After user creation should be 5, got {after_user_count}"
        );

        # Capture document snapshots before read-only ops (to verify no updates)
        import hashlib;
        def get_docs_hash -> str {
            docs = list(collection.find({}, sort=[("_id", 1)]));
            doc_str = str([(d.get("_id"), d.get("data")) for d in docs]);
            return hashlib.sha256(doc_str.encode()).hexdigest();
        }

        docs_hash_before = get_docs_hash();

        # Capture server-side update count before read-only operations
        updates_before_readonly = get_update_count();

        # Make multiple read-only requests
        for _ in range(3) {
            res = requests.post(f"{base_url}/walker/GetAllTasks", json={}, timeout=2);
            assert res.status_code == 200;
        }

        # Count should remain the same - no writes should occur
        after_readonly_count = collection.count_documents({});
        assert after_readonly_count == after_user_count , (
            f"Read-only operations should not create new docs. "
            f"Expected {after_user_count}, got {after_readonly_count}"
        );

        # Verify documents weren't modified (content hash should match)
        docs_hash_after = get_docs_hash();
        assert docs_hash_before == docs_hash_after , (
            "Read-only operations should not modify existing documents in MongoDB"
        );

        # Verify no update operations were issued to MongoDB during read-only requests.
        updates_after_readonly = get_update_count();
        assert updates_after_readonly == updates_before_readonly , (
            f"Read-only operations should not issue any MongoDB update commands. "
            f"Got {updates_after_readonly - updates_before_readonly} unexpected updates"
        );

        # Now create a task (this should write)
        post_request(
            base_url, "/walker/CreateTask", {"id": 999, "title": "Test"}, token
        );

        after_write_count = collection.count_documents({});
        assert after_write_count > after_readonly_count , (
            "Write operation should increase doc count"
        );

        # Another read should not change the count
        requests.post(f"{base_url}/walker/GetAllTasks", json={}, timeout=2);
        final_count = collection.count_documents({});
        assert final_count == after_write_count , (
            f"Final count after read should match previous count. "
            f"Expected {after_write_count}, got {final_count}"
        );
    } finally {
        if server {
            server.terminate();
            with contextlib.suppress(Exception) {
                server.wait(timeout=2);
            }
        }

        if data_dir.exists() {
            import shutil;
            shutil.rmtree(data_dir);
        }
    }
}


test "data persists after server restart for sqlite" {
    if not JAC_FILE.exists() {
        raise FileNotFoundError(f"Missing Jac file: {JAC_FILE}");
    }

    data_dir = FIXTURES_DIR / ".jac" / "data";
    if data_dir.exists() {
        import shutil;
        shutil.rmtree(data_dir);
    }

    # Ensure no MongoDB or Redis environment variables are set (SQLite-only mode)
    env_backup = {};
    for key in ["MONGODB_URI", "REDIS_URL"] {
        if key in os.environ {
            env_backup[key] = os.environ[key];
            del os.environ[key];
        }
    }

    port = get_free_port();
    base_url = f"http://localhost:{port}";
    server = start_server(FIXTURES_DIR, JAC_FILE, port);

    try {
        # Create a task
        res = requests.post(
            f"{base_url}/walker/CreateTask",
            json={"id": 401, "title": "Persist me across restart"},
            timeout=2
        );
        assert res.status_code == 200 , f"Task creation failed: {res.status_code} - {res.text}";

        # Verify task exists before restart
        res = requests.post(f"{base_url}/walker/GetAllTasks", json={}, timeout=5);
        response_data = cast(
            dict[str, Any], extract_transport_response_data(res.json())
        );
        tasks_before = response_data["reports"][0];
        assert len(tasks_before) == 1 , f"Should have 1 task before restart, got {len(
            tasks_before
        )}";
        assert tasks_before[0]["id"] == 401 , f"Task id should be 401, got {tasks_before[
            0
        ]['id']}";
        assert tasks_before[0]["title"] == "Persist me across restart" , f"Task title mismatch: {tasks_before[
            0
        ]['title']}";

        # Restart server
        server.terminate();
        server.wait(timeout=2);
        server = start_server(FIXTURES_DIR, JAC_FILE, port);

        # Verify task persists after restart
        res = requests.post(f"{base_url}/walker/GetAllTasks", json={}, timeout=5);
        assert res.status_code == 200 , f"Post-restart request failed: {res.status_code}";
        response_data = cast(
            dict[str, Any], extract_transport_response_data(res.json())
        );
        tasks_after = response_data["reports"][0];
        assert len(tasks_after) == 1 , f"Task should persist after SQLite restart, got {len(
            tasks_after
        )}";
        assert tasks_after[0]["id"] == 401 , f"Task id should be 401 after restart, got {tasks_after[
            0
        ]['id']}";
        assert tasks_after[0]["title"] == "Persist me across restart" , f"Task title mismatch after restart: {tasks_after[
            0
        ]['title']}";
    } finally {
        if server {
            server.terminate();
            with contextlib.suppress(Exception) {
                server.wait(timeout=2);
            }
        }

        # Restore environment variables
        for (key, value) in env_backup.items() {
            os.environ[key] = value;
        }

        if data_dir.exists() {
            import shutil;
            shutil.rmtree(data_dir);
        }
    }
}

test "L2 and L3 commit with server restart" {
    # Verify that modifications persist across server restarts (L3)
    # and that L2 caching works after reads
    if not JAC_FILE.exists() {
        raise FileNotFoundError(f"Missing Jac file: {JAC_FILE}");
    }

    data_dir = FIXTURES_DIR / ".jac" / "data";
    if data_dir.exists() {
        import shutil;
        shutil.rmtree(data_dir);
    }

    _reset_mongo();
    _reset_redis();
    (mongo_client, mongo_uri) = _get_mongo();
    (redis_client, redis_url) = _get_redis();
    os.environ["MONGODB_URI"] = mongo_uri;
    os.environ["REDIS_URL"] = redis_url;

    port = get_free_port();
    base_url = f"http://localhost:{port}";
    server = start_server(FIXTURES_DIR, JAC_FILE, port);

    try {
        db = mongo_client["jac_db"];
        collection = db["_anchors"];

        # Verify initial state in MongoDB
        initial_mongo_count = collection.count_documents({});
        assert initial_mongo_count == 4 , (
            f"Initial MongoDB should have 4 docs (super root, guest_user, admin, __system__), got {initial_mongo_count}"
        );

        # Verify initial Redis state (4 initial nodes are cached on startup)
        initial_redis_count = redis_client.dbsize();
        assert initial_redis_count == 4 , (
            f"Redis should have 4 initial entries (super root, guest_user, admin, __system__) on startup, got {initial_redis_count} keys"
        );

        # Register a user to ensure proper caching behavior (authenticated requests)
        token = register_user(base_url, "testuser", "testpass");

        # Create and verify task with authenticated request
        res = requests.post(
            f"{base_url}/walker/CreateTask",
            json={"id": 500, "title": "L2/L3 Test"},
            headers={"Authorization": f"Bearer {token}"},
            timeout=2
        );
        assert res.status_code == 200;

        # DIRECT MONGODB VERIFICATION: Check task was written to L3
        mongo_count_after_create = collection.count_documents({});
        assert mongo_count_after_create == 7 , (
            f"After task creation, MongoDB should have 7 docs (4 initial + 1 user + 2 for task node and edge), got {mongo_count_after_create}"
        );

        # Verify task data exists in MongoDB - search all documents
        all_docs_in_mongo = list(collection.find({}));
        task_node_found = False;
        for doc in all_docs_in_mongo {
            data_str = str(doc.get("data", ""));
            # Check for task with id=500 in any format
            if "500" in data_str and "L2/L3 Test" in data_str {
                task_node_found = True;
                break;
            }
        }
        assert task_node_found , f"Task with id=500 and title='L2/L3 Test' should exist in MongoDB (L3). Checked {len(
            all_docs_in_mongo
        )} total docs";

        # Read task via API to trigger L2 caching (use authenticated request)
        res = requests.post(
            f"{base_url}/walker/GetAllTasks",
            json={},
            headers={"Authorization": f"Bearer {token}"},
            timeout=2
        );
        response_data = cast(
            dict[str, Any], extract_transport_response_data(res.json())
        );
        tasks_before = response_data["reports"][0];
        assert len(tasks_before) == 1 , "Should have 1 task before restart";
        assert tasks_before[0]["id"] == 500;

        # DIRECT REDIS VERIFICATION: Check exact key count and task data
        redis_count_after_read = redis_client.dbsize();
        assert redis_count_after_read == 7 , (
            f"After read, Redis (L2) should have exactly 7 entries (4 initial + user + task node + edge), got {redis_count_after_read}"
        );

        # Verify actual task data is cached in Redis
        redis_keys = redis_client.keys("*");
        task_found_in_redis = False;
        for key in redis_keys {
            val = redis_client.get(key);
            if val
            and b"Task" in val
            and b'"id": 500' in val
            and b'"title": "L2/L3 Test"' in val {
                task_found_in_redis = True;
                break;
            }
        }
        assert task_found_in_redis , "Task with id=500 and full title should be cached in Redis (L2)";

        # Restart server to verify L3 persistence
        server.terminate();
        server.wait(timeout=2);
        redis_client.flushall();  # Clear L2 to force read from L3

        # Verify Redis is actually empty after flush
        redis_count_after_flush = redis_client.dbsize();
        assert redis_count_after_flush == 0 , f"Redis should be empty after flush, got {redis_count_after_flush} keys";

        # VERIFY MONGODB STILL HAS DATA (L3 persistence)
        mongo_count_before_restart = collection.count_documents({});
        assert mongo_count_before_restart == 7 , (
            f"MongoDB should still have 7 docs after Redis flush, got {mongo_count_before_restart}"
        );

        # Verify task still exists in MongoDB before restart
        task_still_in_mongo = False;
        for doc in collection.find({}) {
            data_str = str(doc.get("data", ""));
            if "500" in data_str and "L2/L3 Test" in data_str {
                task_still_in_mongo = True;
                break;
            }
        }
        assert task_still_in_mongo , "Task should still exist in MongoDB (L3) before server restart";

        server = start_server(FIXTURES_DIR, JAC_FILE, port);

        # Login as existing user after server restart (user persisted in MongoDB)
        res = requests.post(
            f"{base_url}/user/login",
            json={
                "identity": {"type": "username", "value": "testuser"},
                "credential": {"type": "password", "password": "testpass"}
            },
            timeout=2
        );
        assert res.status_code == 200 , f"Login failed: {res.status_code} - {res.text}";
        login_data = cast(dict[str, Any], extract_transport_response_data(res.json()));
        token_after_restart = login_data["token"];

        # Verify task persists after restart (proves L3 commit worked) - use authenticated request
        res = requests.post(
            f"{base_url}/walker/GetAllTasks",
            json={},
            headers={"Authorization": f"Bearer {token_after_restart}"},
            timeout=2
        );
        response_data = cast(
            dict[str, Any], extract_transport_response_data(res.json())
        );
        tasks_after = response_data["reports"][0];
        assert len(tasks_after) == 1 , "Task should persist after restart (L3 commit)";
        assert tasks_after[0]["id"] == 500;
        assert tasks_after[0]["title"] == "L2/L3 Test";

        # VERIFY MONGODB UNCHANGED AFTER RESTART (still has same 7 docs)
        mongo_count_after_restart = collection.count_documents({});
        assert mongo_count_after_restart == 7 , (
            f"MongoDB should still have 7 docs after restart (4 initial + user + 2 task), got {mongo_count_after_restart}"
        );
    } finally {
        if server {
            server.terminate();
            with contextlib.suppress(Exception) {
                server.wait(timeout=2);
            }
        }
        if data_dir.exists() {
            import shutil;
            shutil.rmtree(data_dir);
        }
    }
}

test "Redis write cycle via commit" {
    if not JAC_FILE.exists() {
        raise FileNotFoundError(f"Missing Jac file: {JAC_FILE}");
    }

    data_dir = FIXTURES_DIR / ".jac" / "data";
    if data_dir.exists() {
        import shutil;
        shutil.rmtree(data_dir);
    }

    _reset_mongo();
    _reset_redis();
    (_, mongo_uri) = _get_mongo();
    (redis_client, redis_url) = _get_redis();
    os.environ["MONGODB_URI"] = mongo_uri;
    os.environ["REDIS_URL"] = redis_url;

    port = get_free_port();
    base_url = f"http://localhost:{port}";
    server = start_server(FIXTURES_DIR, JAC_FILE, port);

    try {
        # Initial: 4 nodes in Redis (super_root, guest, admin, __system__)
        assert redis_client.dbsize() == 4 , "Redis should start with 4 initial nodes";

        # Create task
        res = requests.post(
            f"{base_url}/walker/CreateTask",
            json={"id": 999, "title": "Redis Write Test"},
            timeout=2
        );
        assert res.status_code == 200;

        # HARSH CHECK: Task MUST be in Redis after creation+commit
        redis_keys = redis_client.keys("*");
        task_in_redis = False;
        for key in redis_keys {
            val = redis_client.get(key);
            if val and b'"id": 999' in val and b'"title": "Redis Write Test"' in val {
                task_in_redis = True;
                break;
            }
        }
        assert task_in_redis , (
            "FAIL: Task with id=999 NOT in Redis after creation. "
            "Redis write cycle via commit() is BROKEN!"
        );

        # Count must increase (4 initial + task node + edge = 6)
        final_count = redis_client.dbsize();
        assert final_count == 6 , (
            f"Redis should have 6 entries after task creation, got {final_count}"
        );
    } finally {
        if server {
            server.terminate();
            with contextlib.suppress(Exception) {
                server.wait(timeout=2);
            }
        }
        if data_dir.exists() {
            import shutil;
            shutil.rmtree(data_dir);
        }
    }
}

test "hash-based dirty check detects all mutation types" {
    import from jaclang.runtimelib.serializer { Serializer }
    import sys;
    sys.path.insert(0, str(FIXTURES_DIR));
    import from mutation_app { Item }

    # Create an Item with mutable fields
    item = Item(id=1);
    anchor = item.__jac__;

    # New anchor has hash=0 (never persisted)
    assert anchor.hash == 0 , "New anchor should have hash=0";

    # Simulate persist: compute and store baseline hash
    anchor.hash = Serializer._compute_hash(anchor);
    baseline = anchor.hash;
    assert baseline != 0 , "Computed hash should be non-zero";

    # No mutation → hash unchanged
    assert Serializer._compute_hash(anchor) == baseline , "No mutation should yield same hash";

    # Direct field assignment
    item.completed = True;
    assert Serializer._compute_hash(anchor) != baseline , "Direct assignment should change hash";

    # Reset baseline
    anchor.hash = Serializer._compute_hash(anchor);
    baseline = anchor.hash;

    # In-place list mutation
    item.tags.append("urgent");
    assert Serializer._compute_hash(anchor) != baseline , "list.append should change hash";

    # Reset baseline
    anchor.hash = Serializer._compute_hash(anchor);
    baseline = anchor.hash;

    # In-place dict mutation
    item.metadata["priority"] = "high";
    assert Serializer._compute_hash(anchor) != baseline , "dict[k]=v should change hash";
}

test "sequential requests work correctly" {
    # Validates: Multiple sequential requests don't cause crashes or data corruption
    _reset_mongo();
    (_, mongo_uri) = _get_mongo();
    os.environ["MONGODB_URI"] = mongo_uri;
    if "REDIS_URL" in os.environ {
        del os.environ["REDIS_URL"];
    }

    port = get_free_port();
    base_url = f"http://localhost:{port}";
    server = start_server(FIXTURES_DIR, JAC_FILE, port);

    try {
        # Make 5 sequential requests - all should succeed
        for i in range(5) {
            res = requests.post(
                f"{base_url}/walker/CreateTask",
                json={"id": i, "title": f"Sequential {i}"},
                timeout=5
            );
            assert res.status_code == 200 , f"Request {i} failed";
        }

        # Verify all 5 tasks were created
        res = requests.post(f"{base_url}/walker/GetAllTasks", json={}, timeout=5);
        all_tasks = cast(dict[str, Any], extract_transport_response_data(res.json()))[
            "reports"
        ][0];
        assert len(all_tasks) == 5 , f"Expected 5 tasks, got {len(all_tasks)}";
    } finally {
        server.terminate();
        with contextlib.suppress(Exception) {
            server.wait(timeout=2);
        }
    }
}

test "batch_get reduces MongoDB queries for edge traversals" {
    # Validates: When traversing N edges, batch_get uses $in queries instead of N individual finds.
    # Creates 10 tasks (10 edges + 10 nodes), restarts server to clear L1,
    # then reads all tasks and verifies MongoDB query count is much less than 20.
    if not JAC_FILE.exists() {
        raise FileNotFoundError(f"Missing Jac file: {JAC_FILE}");
    }

    data_dir = FIXTURES_DIR / ".jac" / "data";
    if data_dir.exists() {
        import shutil;
        shutil.rmtree(data_dir);
    }

    _reset_mongo();
    (mongo_client, mongo_uri) = _get_mongo();
    os.environ["MONGODB_URI"] = mongo_uri;

    # No Redis — force all reads through MongoDB to measure query count accurately
    env_backup = {};
    if "REDIS_URL" in os.environ {
        env_backup["REDIS_URL"] = os.environ["REDIS_URL"];
        del os.environ["REDIS_URL"];
    }

    port = get_free_port();
    base_url = f"http://localhost:{port}";
    server = start_server(FIXTURES_DIR, JAC_FILE, port);

    num_tasks = 10;

    try {
        db = mongo_client["jac_db"];
        collection = db["_anchors"];

        # Create N tasks (each creates 1 node + 1 edge = 2 anchors)
        for i in range(num_tasks) {
            res = requests.post(
                f"{base_url}/walker/CreateTask",
                json={"id": i, "title": f"Batch task {i}"},
                timeout=5
            );
            assert res.status_code == 200 , f"Task {i} creation failed: {res.status_code}";
        }

        # Verify all tasks were stored in MongoDB
        # 4 initial + num_tasks * 2 (node + edge per task)
        expected_docs = 4 + num_tasks * 2;
        actual_docs = collection.count_documents({});
        assert actual_docs == expected_docs , (
            f"Expected {expected_docs} docs in MongoDB, got {actual_docs}"
        );

        # Restart server to clear L1 memory — forces reads from L3 (MongoDB)
        server.terminate();
        server.wait(timeout=2);
        server = start_server(FIXTURES_DIR, JAC_FILE, port);

        # Capture MongoDB query count before the read traversal
        server_status_before = mongo_client.admin.command("serverStatus");
        queries_before = server_status_before["opcounters"]["query"];

        # Read all tasks — this triggers _prefetch_edges -> batch_get
        res = requests.post(f"{base_url}/walker/GetAllTasks", json={}, timeout=10);
        assert res.status_code == 200;
        response_data = cast(
            dict[str, Any], extract_transport_response_data(res.json())
        );
        tasks = response_data["reports"][0];
        assert len(tasks) == num_tasks , (
            f"Expected {num_tasks} tasks, got {len(tasks)}"
        );

        # Capture MongoDB query count after read
        server_status_after = mongo_client.admin.command("serverStatus");
        queries_after = server_status_after["opcounters"]["query"];

        # Without batch_get: would need ~20+ individual find() calls (1 per edge + 1 per node)
        # With batch_get: should be ~2-4 calls (batch edges + batch nodes + root load)
        queries_used = queries_after - queries_before;
        max_expected_queries = num_tasks;  # Should be well under N queries
        assert queries_used < max_expected_queries , (
            f"batch_get should reduce queries: used {queries_used} queries to traverse "
            f"{num_tasks} edges, expected fewer than {max_expected_queries}. "
            f"batch_get may not be working."
        );
    } finally {
        if server {
            server.terminate();
            with contextlib.suppress(Exception) {
                server.wait(timeout=2);
            }
        }

        # Restore environment
        for (key, value) in env_backup.items() {
            os.environ[key] = value;
        }

        if data_dir.exists() {
            import shutil;
            shutil.rmtree(data_dir);
        }
    }
}

glob MUTATION_JAC_FILE = FIXTURES_DIR / "mutation_app.jac";

"""Validates that in-place mutations (list.append, dict[k]=v) which bypass
__setattr__ are still detected and persisted through hash comparison."""
test "in-place mutations on list and dict are persisted via hash-based dirty check" {
    _reset_mongo();
    _reset_redis();
    (_, mongo_uri) = _get_mongo();
    (_, redis_url) = _get_redis();
    os.environ["MONGODB_URI"] = mongo_uri;
    os.environ["REDIS_URL"] = redis_url;

    port = get_free_port();
    base_url = f"http://localhost:{port}";
    server: subprocess.Popen = start_server(FIXTURES_DIR, MUTATION_JAC_FILE, port);

    data_dir = FIXTURES_DIR / ".jac" / "data";

    try {
        token = register_user(base_url, "mutation_tester");

        # Create an item
        post_request(base_url, "/walker/CreateItem", {"id": 1}, token);

        # --- In-place list mutation (list.append) ---
        result = post_request(
            base_url, "/walker/AppendTag", {"id": 1, "tag": "urgent"}, token
        );
        assert "urgent" in result["reports"][0]["tags"];

        # --- In-place dict mutation (dict[k]=v) ---
        result = post_request(
            base_url,
            "/walker/SetMeta",
            {"id": 1, "key": "priority", "value": "high"},
            token
        );
        assert result["reports"][0]["metadata"]["priority"] == "high";

        # --- Restart server to force reload from MongoDB ---
        server.terminate();
        with contextlib.suppress(Exception) {
            server.wait(timeout=2);
        }
        server = start_server(FIXTURES_DIR, MUTATION_JAC_FILE, port);

        # Read back after restart — mutations must have been persisted
        result = post_request(base_url, "/walker/GetItems", {}, token);
        items = result["reports"][0];
        assert len(items) == 1 , f"Expected 1 item, got {len(items)}";

        item = items[0];
        assert "urgent" in item["tags"] , (
            f"list.append mutation was not persisted. tags={item['tags']}"
        );
        assert item["metadata"].get("priority") == "high" , (
            f"dict[k]=v mutation was not persisted. metadata={item['metadata']}"
        );
    } finally {
        server.terminate();
        with contextlib.suppress(Exception) {
            server.wait(timeout=2);
        }
        if data_dir.exists() {
            import shutil;
            shutil.rmtree(data_dir);
        }
    }
}

"""Verify that put_partial touches only the mutated field's dot-path in MongoDB."""
test "partial update only writes mutated fields — unmodified fields survive in MongoDB" {
    data_dir = FIXTURES_DIR / ".jac" / "data";
    if data_dir.exists() {
        import shutil;
        shutil.rmtree(data_dir);
    }

    _reset_mongo();
    (mongo_client, mongo_uri) = _get_mongo();
    os.environ["MONGODB_URI"] = mongo_uri;

    env_backup = {};
    if "REDIS_URL" in os.environ {
        env_backup["REDIS_URL"] = os.environ["REDIS_URL"];
        del os.environ["REDIS_URL"];
    }

    port = get_free_port();
    base_url = f"http://localhost:{port}";
    server: subprocess.Popen = start_server(FIXTURES_DIR, MUTATION_JAC_FILE, port);

    try {
        token = register_user(base_url, "sentinel_tester");
        post_request(base_url, "/walker/CreateItem", {"id": 42}, token);

        db = mongo_client["jac_db"];
        collection = db["_anchors"];

        item_doc = collection.find_one({"arch_type": "Item"});
        assert item_doc is not None , "Item not found in MongoDB after creation";
        item_id = item_doc["_id"];

        # Inject a sentinel key directly into the metadata sub-document.
        # A full $set would wipe it; a targeted $set on data.archetype.tags must not.
        collection.update_one(
            {"_id": item_id},
            {"$set": {"data.archetype.metadata.__sentinel__": "PRESERVED"}}
        );
        sentinel_check = collection.find_one({"_id": item_id});
        assert sentinel_check["data"]["archetype"]["metadata"].get("__sentinel__") == "PRESERVED" , (
            "Sentinel injection failed"
        );

        # Mutate only tags (in-place list.append — no __setattr__ signal,
        # goes through field-hash fallback → put_partial on data.archetype.tags only).
        post_request(base_url, "/walker/AppendTag", {"id": 42, "tag": "urgent"}, token);

        doc = collection.find_one({"_id": item_id});
        assert "urgent" in doc["data"]["archetype"]["tags"] , (
            "tags mutation was not persisted to MongoDB"
        );
        assert doc["data"]["archetype"]["metadata"].get("__sentinel__") == "PRESERVED" , (
            "put_partial overwrote metadata — a full $set was issued instead of a partial one"
        );
    } finally {
        server.terminate();
        with contextlib.suppress(Exception) {
            server.wait(timeout=2);
        }
        for (key, value) in env_backup.items() {
            os.environ[key] = value;
        }
        if data_dir.exists() {
            import shutil;
            shutil.rmtree(data_dir);
        }
    }
}


test "mixed direct and in-place mutations in one request both persist after restart" {
    data_dir = FIXTURES_DIR / ".jac" / "data";
    if data_dir.exists() {
        import shutil;
        shutil.rmtree(data_dir);
    }

    _reset_mongo();
    (_, mongo_uri) = _get_mongo();
    os.environ["MONGODB_URI"] = mongo_uri;

    env_backup = {};
    if "REDIS_URL" in os.environ {
        env_backup["REDIS_URL"] = os.environ["REDIS_URL"];
        del os.environ["REDIS_URL"];
    }

    port = get_free_port();
    base_url = f"http://localhost:{port}";
    server: subprocess.Popen = start_server(FIXTURES_DIR, MUTATION_JAC_FILE, port);

    try {
        token = register_user(base_url, "mixed_tester");
        post_request(base_url, "/walker/CreateItem", {"id": 7}, token);

        # MixedMutate does: here.completed = True  (direct → __setattr__ tracks it)
        #                   here.tags.append(tag)  (in-place → only field-hash catches it)
        result = post_request(
            base_url, "/walker/MixedMutate", {"id": 7, "tag": "mixed"}, token
        );
        item = result["reports"][0];
        assert item["completed"] == True , "completed not set in response";
        assert "mixed" in item["tags"] , "tag not in response";

        # Restart with no Redis — forces cold reload from MongoDB only.
        server.terminate();
        with contextlib.suppress(Exception) {
            server.wait(timeout=2);
        }
        server = start_server(FIXTURES_DIR, MUTATION_JAC_FILE, port);

        result = post_request(base_url, "/walker/GetItems", {}, token);
        items = result["reports"][0];
        assert len(items) == 1 , f"Expected 1 item after restart, got {len(items)}";
        item = items[0];
        assert item["completed"] == True , (
            "completed=True (direct assignment) was not persisted after restart"
        );
        assert "mixed" in item["tags"] , (
            "tags.append (in-place mutation) was not persisted after restart — "
            "combined dirty detection failed for mixed mutations"
        );
    } finally {
        server.terminate();
        with contextlib.suppress(Exception) {
            server.wait(timeout=2);
        }
        for (key, value) in env_backup.items() {
            os.environ[key] = value;
        }
        if data_dir.exists() {
            import shutil;
            shutil.rmtree(data_dir);
        }
    }
}


test "concurrent requests do not lose edges" {
    if not JAC_FILE.exists() {
        raise FileNotFoundError(f"Missing Jac file: {JAC_FILE}");
    }

    data_dir = FIXTURES_DIR / ".jac" / "data";
    if data_dir.exists() {
        import shutil;
        shutil.rmtree(data_dir);
    }

    _reset_mongo();
    (_, mongo_uri) = _get_mongo();
    os.environ["MONGODB_URI"] = mongo_uri;
    if "REDIS_URL" in os.environ {
        del os.environ["REDIS_URL"];
    }

    port = get_free_port();
    base_url = f"http://localhost:{port}";
    server = start_server(FIXTURES_DIR, JAC_FILE, port);

    try {
        token = register_user(base_url, "race_user", "pass123");

        # Seed: first CreateTask ensures the root has ≥1 edge before we race
        res = requests.post(
            f"{base_url}/walker/CreateTask",
            json={"id": 1, "title": "first"},
            headers={"Authorization": f"Bearer {token}"},
            timeout=2
        );
        assert res.status_code == 200;

        # The real race: CreateTask adds a new edge to root, while CompleteTask
        # traverses root (loading a stale edge snapshot) and mutates a scalar.
        # On main, CompleteTask's sync overwrites root.edges, erasing the new edge.
        def create_task -> int {
            r = requests.post(
                f"{base_url}/walker/CreateTask",
                json={"id": 2, "title": "survivor"},
                headers={"Authorization": f"Bearer {token}"},
                timeout=5
            );
            return r.status_code;
        }

        def complete_task -> int {
            r = requests.post(
                f"{base_url}/walker/CompleteTask",
                json={"id": 1},
                headers={"Authorization": f"Bearer {token}"},
                timeout=5
            );
            return r.status_code;
        }

        # Fire edge-add + scalar-mutation concurrently (multiple rounds)
        for _ in range(3) {
            with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool {
                futures = [
                    pool.submit(create_task),
                    pool.submit(complete_task),
                    pool.submit(complete_task),
                    pool.submit(complete_task)
                ];
                concurrent.futures.wait(futures);
            }
        }

        # Verify the new task edge survived concurrent scalar mutations
        time.sleep(0.5);
        res = requests.post(
            f"{base_url}/walker/GetAllTasks",
            json={},
            headers={"Authorization": f"Bearer {token}"},
            timeout=2
        );
        response_data = cast(
            dict[str, Any], extract_transport_response_data(res.json())
        );
        tasks = response_data["reports"][0];
        task_titles = [t.get("title", "") for t in tasks];
        assert "survivor" in task_titles , (
            f"Edge lost after concurrent scalar mutations! Got: {task_titles}"
        );
    } finally {
        if server {
            server.terminate();
            with contextlib.suppress(Exception) {
                server.wait(timeout=2);
            }
        }
        if data_dir.exists() {
            import shutil;
            shutil.rmtree(data_dir);
        }
    }
}

"""Unit test for issue 1g fix: ScaleTieredMemory._committed flag.

After the first acommit() the flag is set True. A second call (the
middleware's redundant pass) returns immediately — MongoBackend.sync()
and its O(L1-size) hash computation are skipped entirely.
"""
test "acommit is idempotent — _committed flag prevents second sync pass" {
    import asyncio;
    import from unittest.mock { patch }
    import from jac_scale.memory_hierarchy { ScaleTieredMemory }

    call_count = [0];

    def mock_commit(self: ScaleTieredMemory, anchor: Any = None) {
        call_count[0] += 1;
    }

    with patch.object(ScaleTieredMemory, 'commit', mock_commit) {
        mem = object.__new__(ScaleTieredMemory);
        mem._committed = False;
        asyncio.run(mem.acommit());
        assert call_count[0] == 1 , f"expected 1 commit call after first acommit, got {call_count[
            0
        ]}";
        assert mem._committed is True , "_committed must be True after first acommit";
        asyncio.run(mem.acommit());
        assert call_count[0] == 1 , (
            f"second acommit (middleware pass) must be a no-op via _committed flag, "
            f"but commit() was called {call_count[0]} times"
        );
    }
}

"""Unit test for issue 1g fix: _committed stays False when commit() raises.

If the thread pool commit raises (e.g. MongoDB unreachable), _committed must
remain False so the middleware safety-net path can retry the commit.
"""
test "acommit leaves _committed False when commit() raises" {
    import asyncio;
    import from unittest.mock { patch }
    import from jac_scale.memory_hierarchy { ScaleTieredMemory }

    def failing_commit(self: ScaleTieredMemory, anchor: Any = None) {
        raise RuntimeError("simulated commit failure");
    }

    with patch.object(ScaleTieredMemory, 'commit', failing_commit) {
        mem = object.__new__(ScaleTieredMemory);
        mem._committed = False;
        raised = False;
        try {
            asyncio.run(mem.acommit());
        } except Exception {
            raised = True;
        }
        assert raised , "acommit() must propagate the exception from commit()";
        assert mem._committed is False , (
            "_committed must stay False when commit() raises — "
            "the middleware safety net must still be able to retry"
        );
    }
}


# =============================================================================
# In-process system root cache tests (no server subprocess needed)
# =============================================================================
"""Wipe process-level singletons so each test starts with a cold process cache."""
def _reset_process_cache {
    _process_cache.clear();
    with contextlib.suppress(Exception) {
        close_all_db_connections();
    }
}

"""Create a JScaleExecutionContext pointed at mongo_uri with no Redis."""
def _new_jscale_ctx(mongo_uri: str) -> JScaleExecutionContext {
    os.environ["MONGODB_URI"] = mongo_uri;
    os.environ.pop("REDIS_URL", None);
    return JScaleExecutionContext();
}

"""Return L3 (MongoDB) fetch count for this context, or 0 if not Mongo."""
def _ctx_l3_fetch_count(ctx: JScaleExecutionContext) -> int {
    l3 = ctx.mem.l3;
    if isinstance(l3, MongoBackend) {
        return l3.fetch_count;
    }
    return 0;
}


"""After the very first JScaleExecutionContext(), _process_cache['system_root']
must hold a NodeAnchor whose id equals SUPER_ROOT_UUID."""
test "system root cache: populated with NodeAnchor after first context init" {
    import from uuid { UUID }
    import from jaclang.jac0core.constant { Constants as Con }
    import from jaclang.jac0core.archetype { NodeAnchor }

    _reset_process_cache();
    _reset_mongo();
    (_, uri) = _get_mongo();

    assert "system_root" not in _process_cache;
    _new_jscale_ctx(uri);

    assert "system_root" in _process_cache , (
        "_process_cache must contain 'system_root' after first context init"
    );
    cached = _process_cache["system_root"];
    assert isinstance(cached, NodeAnchor) , (
        f"Cached value must be a NodeAnchor, got {type(cached).__name__}"
    );
    assert cached.id == UUID(Con.SUPER_ROOT_UUID) , (
        f"Cached anchor id {cached.id} != SUPER_ROOT_UUID"
    );
    _reset_process_cache();
}


"""First init must fetch the system root from MongoDB (fetch_count >= 1).
Second init must find it in L1 from the process cache (fetch_count == 0).

Each JScaleExecutionContext creates a fresh MongoBackend with fetch_count=0,
so the count measured is per-context, not cumulative.
"""
test "system root cache: second context init skips MongoDB fetch" {
    _reset_process_cache();
    _reset_mongo();
    (_, uri) = _get_mongo();

    ctx1 = _new_jscale_ctx(uri);
    first_fetches = _ctx_l3_fetch_count(ctx1);
    assert first_fetches >= 1 , (
        f"First context init must fetch system root from MongoDB "
        f"(got fetch_count={first_fetches})"
    );
    assert "system_root" in _process_cache , "Cache must be warm after first init";

    ctx2 = _new_jscale_ctx(uri);
    second_fetches = _ctx_l3_fetch_count(ctx2);
    assert second_fetches == 0 , (
        f"Second context init issued {second_fetches} MongoDB fetch(es) "
        "for system root, expected 0. "
        "_process_cache pre-injection into L1 is not working."
    );
    _reset_process_cache();
}


"""When _process_cache is empty (fresh process), context init must succeed
and set system_root, user_root, and entry_node correctly."""
test "system root cache: cold cache still produces a valid system root" {
    import from uuid { UUID }
    import from jaclang.jac0core.constant { Constants as Con }

    _reset_process_cache();
    _reset_mongo();
    (_, uri) = _get_mongo();

    ctx = _new_jscale_ctx(uri);

    assert ctx.system_root is not None , "system_root must not be None";
    assert ctx.system_root.id == UUID(Con.SUPER_ROOT_UUID) , (
        f"system_root.id {ctx.system_root.id} != SUPER_ROOT_UUID"
    );
    assert ctx.user_root is ctx.system_root , (
        "user_root must default to system_root before auth"
    );
    assert ctx.entry_node is ctx.system_root , (
        "entry_node must default to system_root before auth"
    );
    _reset_process_cache();
}


"""After the first init warms the cache, inits 2..N must each cost 0 fetches.
Total MongoDB fetches for the system root across N inits equals the first
init's fetch count, not N times that."""
test "system root cache: N consecutive inits cost one MongoDB fetch total" {
    N = 10;

    _reset_process_cache();
    _reset_mongo();
    (_, uri) = _get_mongo();

    ctx_first = _new_jscale_ctx(uri);
    first_cost = _ctx_l3_fetch_count(ctx_first);
    assert first_cost >= 1 , "First init must fetch from MongoDB";

    for i in range(N - 1) {
        ctx = _new_jscale_ctx(uri);
        extra = _ctx_l3_fetch_count(ctx);
        assert extra == 0 , (
            f"Context init #{i + 2} of {N} issued {extra} MongoDB fetch(es) "
            "for system root. Expected 0 — cache should be warm."
        );
    }
    _reset_process_cache();
}
