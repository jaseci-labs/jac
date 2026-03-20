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
        timeout=2
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
        timeout=2
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
        # Teardown
        if server {
            server.terminate();
            with contextlib.suppress(Exception) {
                server.wait(timeout=2);
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

        # Clean up data files
        data_dir = FIXTURES_DIR / ".jac" / "data";
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

    # Start MongoDB container
    mongo_container = MongoDbContainer("mongo:latest");
    mongo_container.start();
    mongo_uri = mongo_container.get_connection_url();
    os.environ["MONGODB_URI"] = mongo_uri;

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
        mongo_container.stop();
        time.sleep(0.5);
        gc.collect();

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

    # Start MongoDB container
    mongo_container = MongoDbContainer("mongo:latest");
    mongo_container.start();
    mongo_uri = mongo_container.get_connection_url();
    os.environ["MONGODB_URI"] = mongo_uri;
    mongo_client = MongoClient(mongo_uri);

    # Start Redis container
    redis_container = RedisContainer("redis:latest", port=6379);
    redis_container.start();
    redis_host = redis_container.get_container_host_ip();
    redis_port = redis_container.get_exposed_port(6379);
    redis_url = f"redis://{redis_host}:{redis_port}/0";
    os.environ["REDIS_URL"] = redis_url;

    port = get_free_port();
    base_url = f"http://localhost:{port}";
    server = start_server(FIXTURES_DIR, JAC_FILE, port);

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

        time.sleep(0.5);
        gc.collect();

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

    mongo_container = MongoDbContainer("mongo:latest");
    mongo_container.start();
    mongo_uri = mongo_container.get_connection_url();
    os.environ["MONGODB_URI"] = mongo_uri;
    mongo_client = MongoClient(mongo_uri);

    redis_container = RedisContainer("redis:latest", port=6379);
    redis_container.start();
    redis_host = redis_container.get_container_host_ip();
    redis_port = redis_container.get_exposed_port(6379);
    redis_url = f"redis://{redis_host}:{redis_port}/0";
    os.environ["REDIS_URL"] = redis_url;
    redis_client = redis.Redis(
        host=redis_host, port=int(redis_port), decode_responses=False
    );

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
            json={"username": "testuser", "password": "testpass"},
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

    # Setup MongoDB + Redis
    mongo_container = MongoDbContainer("mongo:latest");
    mongo_container.start();
    mongo_uri = mongo_container.get_connection_url();
    os.environ["MONGODB_URI"] = mongo_uri;

    redis_container = RedisContainer("redis:latest", port=6379);
    redis_container.start();
    redis_host = redis_container.get_container_host_ip();
    redis_port = redis_container.get_exposed_port(6379);
    redis_url = f"redis://{redis_host}:{redis_port}/0";
    os.environ["REDIS_URL"] = redis_url;
    redis_client = redis.Redis(
        host=redis_host, port=int(redis_port), decode_responses=False
    );

    port = get_free_port();
    base_url = f"http://localhost:{port}";
    server = start_server(FIXTURES_DIR, JAC_FILE, port);

    try {
        # Initial: 4 nodes in Redis (super_root, guest, admin, __system__)
        assert redis_client.dbsize() == 4 , "Redis should start with 4 initial nodes";

        # Create task (goes to L1 with is_updated=True, then commit writes to L2)
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
        mongo_container.stop();
        redis_container.stop();
        time.sleep(0.5);
        gc.collect();
        if data_dir.exists() {
            import shutil;
            shutil.rmtree(data_dir);
        }
    }
}

test "is_updated flag set on field modification" {
    # Import the Task node from the fixture
    import sys;
    sys.path.insert(0, str(FIXTURES_DIR));
    import from todo_app { Task }

    # Create a Task instance
    task = Task(id=999, title="Test is_updated", completed=False);
    task_anchor = task.__jac__;

    # After creation, is_updated should be True (new node)
    assert task_anchor.is_updated , "Newly created node should have is_updated=True";

    # Simulate save by setting is_updated=False (as would happen after commit)
    task_anchor.is_updated = False;
    assert not task_anchor.is_updated , "After save simulation, is_updated should be False";

    # Modify a field - this should trigger __setattr__ which sets is_updated=True
    task.completed = True;

    # Verify is_updated was set to True
    assert task_anchor.is_updated , (
        "Modifying 'completed' field should set is_updated=True via __setattr__"
    );

    # Reset flag
    task_anchor.is_updated = False;

    # Modify another field
    task.title = "Modified Title";

    # Verify is_updated was set to True again
    assert task_anchor.is_updated , (
        "Modifying 'title' field should set is_updated=True"
    );
}

test "sequential requests work correctly" {
    # Validates: Multiple sequential requests don't cause crashes or data corruption
    mongo_container = MongoDbContainer("mongo:latest");
    mongo_container.start();
    os.environ["MONGODB_URI"] = mongo_container.get_connection_url();

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
        mongo_container.stop();
        gc.collect();
    }
}
