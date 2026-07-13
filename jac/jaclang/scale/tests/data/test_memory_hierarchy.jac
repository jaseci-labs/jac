import atexit;
import contextlib;
import concurrent.futures;
import os;
import socket;
import subprocess;
import sys;
import time;
import from pathlib { Path }
import from typing { cast }
import redis;
import requests;
import from pymongo { MongoClient }
import from testcontainers.mongodb { MongoDbContainer }
import from testcontainers.redis { RedisContainer }
import from jaclang.jac0core.archetype { Root }
import from jaclang.scale.memory.context { JScaleExecutionContext }
import from jaclang.scale.memory.memory_hierarchy { _process_cache, MongoBackend }
import from jaclang.scale.persistence.db { close_all_db_connections }

def get_free_port -> int {
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s {
        s.bind(("", 0));
        return s.getsockname()[1];
    }
}

obj _FakeL1 {
    has __mem__: dict;
}

glob FIXTURES_DIR = Path(__file__).parent.parent / "fixtures",
     JAC_FILE = FIXTURES_DIR / "todo_app.jac",
     _shared: dict = {};

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

def _reset_mongo -> None {
    if "mongo_client" not in _shared {
        return;
    }
    system_dbs = {"admin", "config", "local"};
    for db_name in _shared["mongo_client"].list_database_names() {
        if db_name not in system_dbs {
            _shared["mongo_client"].drop_database(db_name);
        }
    }
}

def _reset_redis {
    if "redis_client" in _shared {
        _shared["redis_client"].flushall();
    }
}

def extract_transport_response_data(
    json_response: dict[str, any] | list[any]
) -> dict[str, any] | list[any] {
    if isinstance(json_response, list) {
        if len(json_response) == 2 {
            body: dict[str, any] = json_response[1];
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
            result: dict[str, any] = {
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
        dict[str, any], extract_transport_response_data(login_res.json())
    );
    return login_data["token"];
}

def post_request(
    base_url: str, path: str, payload: dict, token: str
) -> dict[str, any] {
    res = requests.post(
        f"{base_url}{path}",
        json=payload,
        headers={"Authorization": f"Bearer {token}"},
        timeout=2
    );
    assert res.status_code == 200 , f"POST {path} failed: {res.status_code} - {res.text}";
    return cast(dict[str, any], extract_transport_response_data(res.json()));
}

def start_server(fixtures_dir: Path, jac_file: Path, port: int) -> subprocess.Popen {
    import from jaclang.scale.runtime.context.util { jac_executable }
    cmd = [jac_executable(), "start", str(jac_file.name), "--port", str(port)];

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

        token = register_user(base_url, "reader", "pass123");

        mongo_doc_after_user_creation_count = collection.count_documents({});
        assert mongo_doc_after_user_creation_count == 5 , (
            "After user creation docs should be 5 (super root, guest_user, admin, __system__, created user)"
        );

        redis_size_before_task_creation = redis_client.dbsize();

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
        res = requests.post(
            f"{base_url}/walker/CreateTask",
            json={"id": 100, "title": "Test persistence"},
            timeout=2
        );
        assert res.status_code == 200;

        res = requests.post(f"{base_url}/walker/GetAllTasks", json={}, timeout=5);
        response_data = cast(
            dict[str, any], extract_transport_response_data(res.json())
        );
        tasks_before = response_data["reports"][0];
        assert len(tasks_before) == 1 , "Should have 1 task before restart";
        assert tasks_before[0]["id"] == 100 , f"Task id should be 100, got {tasks_before[
            0
        ]['id']}";
        assert tasks_before[0]["title"] == "Test persistence" , f"Task title mismatch: {tasks_before[
            0
        ]['title']}";

        server.terminate();
        server.wait(timeout=2);
        server = start_server(FIXTURES_DIR, JAC_FILE, port);

        res = requests.post(f"{base_url}/walker/GetAllTasks", json={}, timeout=2);
        response_data = cast(
            dict[str, any], extract_transport_response_data(res.json())
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

        initial_count = collection.count_documents({});
        assert initial_count == 4 , (f"Initial count should be 4, got {initial_count}");

        token = register_user(base_url, "readonly_user", "pass123");

        after_user_count = collection.count_documents({});
        assert after_user_count == 5 , (
            f"After user creation should be 5, got {after_user_count}"
        );

        import hashlib;
        def get_docs_hash -> str {
            docs = list(collection.find({}, sort=[("_id", 1)]));
            doc_str = str([(d.get("_id"), d.get("data")) for d in docs]);
            return hashlib.sha256(doc_str.encode()).hexdigest();
        }

        docs_hash_before = get_docs_hash();

        updates_before_readonly = get_update_count();

        for _ in range(3) {
            res = requests.post(f"{base_url}/walker/GetAllTasks", json={}, timeout=2);
            assert res.status_code == 200;
        }

        after_readonly_count = collection.count_documents({});
        assert after_readonly_count == after_user_count , (
            f"Read-only operations should not create new docs. "
            f"Expected {after_user_count}, got {after_readonly_count}"
        );

        docs_hash_after = get_docs_hash();
        assert docs_hash_before == docs_hash_after , (
            "Read-only operations should not modify existing documents in MongoDB"
        );

        updates_after_readonly = get_update_count();
        assert updates_after_readonly == updates_before_readonly , (
            f"Read-only operations should not issue any MongoDB update commands. "
            f"Got {updates_after_readonly - updates_before_readonly} unexpected updates"
        );

        post_request(
            base_url, "/walker/CreateTask", {"id": 999, "title": "Test"}, token
        );

        after_write_count = collection.count_documents({});
        assert after_write_count > after_readonly_count , (
            "Write operation should increase doc count"
        );

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
        res = requests.post(
            f"{base_url}/walker/CreateTask",
            json={"id": 401, "title": "Persist me across restart"},
            timeout=2
        );
        assert res.status_code == 200 , f"Task creation failed: {res.status_code} - {res.text}";

        res = requests.post(f"{base_url}/walker/GetAllTasks", json={}, timeout=5);
        response_data = cast(
            dict[str, any], extract_transport_response_data(res.json())
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

        server.terminate();
        server.wait(timeout=2);
        server = start_server(FIXTURES_DIR, JAC_FILE, port);

        res = requests.post(f"{base_url}/walker/GetAllTasks", json={}, timeout=5);
        assert res.status_code == 200 , f"Post-restart request failed: {res.status_code}";
        response_data = cast(
            dict[str, any], extract_transport_response_data(res.json())
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

        initial_mongo_count = collection.count_documents({});
        assert initial_mongo_count == 4 , (
            f"Initial MongoDB should have 4 docs (super root, guest_user, admin, __system__), got {initial_mongo_count}"
        );

        initial_redis_count = redis_client.dbsize();
        assert initial_redis_count == 4 , (
            f"Redis should have 4 initial entries (super root, guest_user, admin, __system__) on startup, got {initial_redis_count} keys"
        );

        token = register_user(base_url, "testuser", "testpass");

        res = requests.post(
            f"{base_url}/walker/CreateTask",
            json={"id": 500, "title": "L2/L3 Test"},
            headers={"Authorization": f"Bearer {token}"},
            timeout=2
        );
        assert res.status_code == 200;

        mongo_count_after_create = collection.count_documents({});
        assert mongo_count_after_create == 7 , (
            f"After task creation, MongoDB should have 7 docs (4 initial + 1 user + 2 for task node and edge), got {mongo_count_after_create}"
        );

        all_docs_in_mongo = list(collection.find({}));
        task_node_found = False;
        for doc in all_docs_in_mongo {
            data_str = str(doc.get("data", ""));

            if "500" in data_str and "L2/L3 Test" in data_str {
                task_node_found = True;
                break;
            }
        }
        assert task_node_found , f"Task with id=500 and title='L2/L3 Test' should exist in MongoDB (L3). Checked {len(
            all_docs_in_mongo
        )} total docs";

        res = requests.post(
            f"{base_url}/walker/GetAllTasks",
            json={},
            headers={"Authorization": f"Bearer {token}"},
            timeout=2
        );
        response_data = cast(
            dict[str, any], extract_transport_response_data(res.json())
        );
        tasks_before = response_data["reports"][0];
        assert len(tasks_before) == 1 , "Should have 1 task before restart";
        assert tasks_before[0]["id"] == 500;

        redis_count_after_read = redis_client.dbsize();
        assert redis_count_after_read == 7 , (
            f"After read, Redis (L2) should have exactly 7 entries (4 initial + user + task node + edge), got {redis_count_after_read}"
        );

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

        server.terminate();
        server.wait(timeout=2);
        redis_client.flushall();

        redis_count_after_flush = redis_client.dbsize();
        assert redis_count_after_flush == 0 , f"Redis should be empty after flush, got {redis_count_after_flush} keys";

        mongo_count_before_restart = collection.count_documents({});
        assert mongo_count_before_restart == 7 , (
            f"MongoDB should still have 7 docs after Redis flush, got {mongo_count_before_restart}"
        );

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

        res = requests.post(
            f"{base_url}/user/login",
            json={
                "identity": {"type": "username", "value": "testuser"},
                "credential": {"type": "password", "password": "testpass"}
            },
            timeout=2
        );
        assert res.status_code == 200 , f"Login failed: {res.status_code} - {res.text}";
        login_data = cast(dict[str, any], extract_transport_response_data(res.json()));
        token_after_restart = login_data["token"];

        res = requests.post(
            f"{base_url}/walker/GetAllTasks",
            json={},
            headers={"Authorization": f"Bearer {token_after_restart}"},
            timeout=2
        );
        response_data = cast(
            dict[str, any], extract_transport_response_data(res.json())
        );
        tasks_after = response_data["reports"][0];
        assert len(tasks_after) == 1 , "Task should persist after restart (L3 commit)";
        assert tasks_after[0]["id"] == 500;
        assert tasks_after[0]["title"] == "L2/L3 Test";

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
        assert redis_client.dbsize() == 4 , "Redis should start with 4 initial nodes";

        res = requests.post(
            f"{base_url}/walker/CreateTask",
            json={"id": 999, "title": "Redis Write Test"},
            timeout=2
        );
        assert res.status_code == 200;

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

        final_count = redis_client.dbsize();
        assert final_count == 5 , (
            f"Redis should have 5 entries after task creation, got {final_count}"
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

    item = Item(id=1);
    anchor = item.__jac__;

    assert anchor.hash == 0 , "New anchor should have hash=0";

    anchor.hash = Serializer._compute_hash(anchor);
    baseline = anchor.hash;
    assert baseline != 0 , "Computed hash should be non-zero";

    assert Serializer._compute_hash(anchor) == baseline , "No mutation should yield same hash";

    item.completed = True;
    assert Serializer._compute_hash(anchor) != baseline , "Direct assignment should change hash";

    anchor.hash = Serializer._compute_hash(anchor);
    baseline = anchor.hash;

    item.tags.append("urgent");
    assert Serializer._compute_hash(anchor) != baseline , "list.append should change hash";

    anchor.hash = Serializer._compute_hash(anchor);
    baseline = anchor.hash;

    item.metadata["priority"] = "high";
    assert Serializer._compute_hash(anchor) != baseline , "dict[k]=v should change hash";
}

test "sequential requests work correctly" {
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
        for i in range(5) {
            res = requests.post(
                f"{base_url}/walker/CreateTask",
                json={"id": i, "title": f"Sequential {i}"},
                timeout=5
            );
            assert res.status_code == 200 , f"Request {i} failed";
        }

        res = requests.post(f"{base_url}/walker/GetAllTasks", json={}, timeout=5);
        all_tasks = cast(dict[str, any], extract_transport_response_data(res.json()))[
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

        for i in range(num_tasks) {
            res = requests.post(
                f"{base_url}/walker/CreateTask",
                json={"id": i, "title": f"Batch task {i}"},
                timeout=5
            );
            assert res.status_code == 200 , f"Task {i} creation failed: {res.status_code}";
        }

        expected_docs = 4 + num_tasks * 2;
        actual_docs = collection.count_documents({});
        assert actual_docs == expected_docs , (
            f"Expected {expected_docs} docs in MongoDB, got {actual_docs}"
        );

        server.terminate();
        server.wait(timeout=2);
        server = start_server(FIXTURES_DIR, JAC_FILE, port);

        server_status_before = mongo_client.admin.command("serverStatus");
        queries_before = server_status_before["opcounters"]["query"];

        res = requests.post(f"{base_url}/walker/GetAllTasks", json={}, timeout=10);
        assert res.status_code == 200;
        response_data = cast(
            dict[str, any], extract_transport_response_data(res.json())
        );
        tasks = response_data["reports"][0];
        assert len(tasks) == num_tasks , (
            f"Expected {num_tasks} tasks, got {len(tasks)}"
        );

        server_status_after = mongo_client.admin.command("serverStatus");
        queries_after = server_status_after["opcounters"]["query"];

        queries_used = queries_after - queries_before;
        max_expected_queries = num_tasks;
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

        post_request(base_url, "/walker/CreateItem", {"id": 1}, token);

        result = post_request(
            base_url, "/walker/AppendTag", {"id": 1, "tag": "urgent"}, token
        );
        assert "urgent" in result["reports"][0]["tags"];

        result = post_request(
            base_url,
            "/walker/SetMeta",
            {"id": 1, "key": "priority", "value": "high"},
            token
        );
        assert result["reports"][0]["metadata"]["priority"] == "high";

        server.terminate();
        with contextlib.suppress(Exception) {
            server.wait(timeout=2);
        }
        server = start_server(FIXTURES_DIR, MUTATION_JAC_FILE, port);

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

        collection.update_one(
            {"_id": item_id},
            {"$set": {"data.archetype.metadata.__sentinel__": "PRESERVED"}}
        );
        sentinel_check = collection.find_one({"_id": item_id});
        assert sentinel_check["data"]["archetype"]["metadata"].get("__sentinel__") == "PRESERVED" , (
            "Sentinel injection failed"
        );

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

        result = post_request(
            base_url, "/walker/MixedMutate", {"id": 7, "tag": "mixed"}, token
        );
        item = result["reports"][0];
        assert item["completed"] == True , "completed not set in response";
        assert "mixed" in item["tags"] , "tag not in response";

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

        res = requests.post(
            f"{base_url}/walker/CreateTask",
            json={"id": 1, "title": "first"},
            headers={"Authorization": f"Bearer {token}"},
            timeout=2
        );
        assert res.status_code == 200;

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

        time.sleep(0.5);
        res = requests.post(
            f"{base_url}/walker/GetAllTasks",
            json={},
            headers={"Authorization": f"Bearer {token}"},
            timeout=2
        );
        response_data = cast(
            dict[str, any], extract_transport_response_data(res.json())
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

test "acommit forwards anchor argument to commit()" {
    import asyncio;
    import from unittest.mock { patch }
    import from jaclang.scale.memory.memory_hierarchy { ScaleTieredMemory }

    received: list = [None];

    def capture_commit(self: ScaleTieredMemory, anchor: any = None) {
        received[0] = anchor;
    }

    with patch.object(ScaleTieredMemory, 'commit', capture_commit) {
        mem = object.__new__(ScaleTieredMemory);
        asyncio.run(mem.acommit());
        assert received[0] is None , (
            f"acommit() with no anchor must pass None to commit(), got {received[0]}"
        );
        sentinel = object();
        asyncio.run(mem.acommit(sentinel));
        assert received[0] is sentinel , (
            "acommit(anchor) must forward the anchor to commit(); "
            f"commit() received {received[0]!r} instead"
        );
    }
}

test "acommit is idempotent — _committed flag prevents second sync pass" {
    import asyncio;
    import from unittest.mock { patch }
    import from jaclang.scale.memory.memory_hierarchy { ScaleTieredMemory }

    call_count = [0];

    def mock_commit(self: ScaleTieredMemory, anchor: any = None) {
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

test "acommit leaves _committed False when commit() raises" {
    import asyncio;
    import from unittest.mock { patch }
    import from jaclang.scale.memory.memory_hierarchy { ScaleTieredMemory }

    def failing_commit(self: ScaleTieredMemory, anchor: any = None) {
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


def _reset_process_cache {
    _process_cache.clear();
    with contextlib.suppress(Exception) {
        close_all_db_connections();
    }
}

def _new_jscale_ctx(mongo_uri: str) -> JScaleExecutionContext {
    os.environ["MONGODB_URI"] = mongo_uri;
    os.environ.pop("REDIS_URL", None);
    return JScaleExecutionContext();
}

def _ctx_l3_fetch_count(ctx: JScaleExecutionContext) -> int {
    l3 = ctx.mem.l3;
    if isinstance(l3, MongoBackend) {
        return l3.fetch_count;
    }
    return 0;
}


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


test "L2 Redis is invalidated (not re-poisoned) after edge-delta atomic write (issue 6295)" {
    import json;
    import from uuid { uuid4, UUID }
    import from jaclang.jac0core.archetype { EdgeAnchor, NodeAnchor }
    import from jaclang.runtimelib.utils { to_uuid }
    import from jaclang.scale.memory.memory_hierarchy {
        ScaleTieredMemory,
        MongoBackend
    }

    _reset_mongo();
    _reset_redis();
    _reset_process_cache();
    _mongo_result = _get_mongo();
    _redis_result = _get_redis();
    mongo_uri: str = cast(str, _mongo_result[1]);
    redis_client: any = _redis_result[0];
    redis_url: str = cast(str, _redis_result[1]);

    os.environ["MONGODB_URI"] = mongo_uri;
    os.environ["REDIS_URL"] = redis_url;

    try {
        mem = ScaleTieredMemory();
        mem.postinit();
        assert mem.l3 is not None , "MongoDB must be available for this test";
        assert mem.l2 is not None , "Redis must be available for this test";

        col: any = cast(MongoBackend, mem.l3).collection;

        root_id: str = str(uuid4());
        col.insert_one(
            {
                '_id': root_id,
                'type': 'NodeAnchor',
                'arch_module': 'jaclang.jac0core.archetype',
                'arch_type': 'Root',
                'fingerprint': None,
                'data': {
                    '__type__': 'NodeAnchor',
                    '__module__': 'jaclang.jac0core.archetype',
                    'id': root_id,
                    'persistent': True,
                    'archetype': {
                        '__type__': 'Root',
                        '__module__': 'jaclang.jac0core.archetype'
                    },
                    'edges': []
                },
                'format_version': 1,
                'updated_at': '2026-01-01T00:00:00'
            }
        );

        root_anchor = mem.get(UUID(root_id));
        assert root_anchor is not None , "root must load from Mongo";
        _raw_after_read: any = redis_client.get(f"anchor:{root_id}");
        assert _raw_after_read is not None , "root must be cached in Redis after tiered read";
        assert json.loads(cast(bytes, _raw_after_read)).get('edges', []) == [] , (
            "L2 must show empty edges at this point (pre-write state)"
        );

        node_anchor = cast(NodeAnchor, root_anchor);
        setattr(node_anchor, '_initial_edge_ids', frozenset());
        edge_id: str = str(uuid4());
        edge_stub = EdgeAnchor.__new__(EdgeAnchor);
        setattr(edge_stub, 'id', to_uuid(edge_id));
        setattr(edge_stub, 'persistent', True);
        node_anchor.edges.append(edge_stub);
        setattr(node_anchor, 'hash', 0);
        mem.__mem__[UUID(root_id)] = node_anchor;

        mem.commit();

        _mongo_doc: any = col.find_one({'_id': root_id});
        l3_edges: list[str] = cast(
            list[str], _mongo_doc.get('data', {}).get('edges', [])
        );
        assert edge_id in l3_edges , (
            f"L3 (Mongo) must contain the new edge after commit; got {l3_edges}"
        );

        l2_raw: any = redis_client.get(f"anchor:{root_id}");
        if l2_raw is not None {
            l2_edges: list[str] = cast(
                list[str], json.loads(cast(bytes, l2_raw)).get('edges', [])
            );
            assert l2_edges != [] , (
                "L2 (Redis) must NOT cache empty edges when L3 has the edge "
                "(issue #6295 regression)"
            );
            assert edge_id in l2_edges , (
                f"L2 edges must match L3 after commit; L3={l3_edges}, L2={l2_edges}"
            );
        }

        initial_ids: frozenset[UUID] = cast(
            frozenset[UUID], getattr(node_anchor, '_initial_edge_ids', frozenset())
        );
        assert len(initial_ids) > 0 , (
            "_initial_edge_ids must be non-empty after _put_node_atomic read-back"
        );
        assert to_uuid(edge_id) in initial_ids , (
            f"_initial_edge_ids must include the merged edge; got {initial_ids}"
        );

        mem.l3.close();
    } finally {
        os.environ.pop("MONGODB_URI", None);
        os.environ.pop("REDIS_URL", None);
        _reset_process_cache();
    }
}

test "L1 invalidation: marks every sibling stale, skips origin, never pops" {
    import from uuid { uuid4 }
    import from jaclang.scale.memory.l1_invalidation {
        register_l1,
        deregister_l1,
        evict_local_l1,
        consume_stale,
        new_l1_id
    }

    anchor_id = uuid4();
    id_a = new_l1_id();
    id_b = new_l1_id();
    id_c = new_l1_id();
    mem_a = _FakeL1(__mem__={anchor_id: "A"});
    mem_b = _FakeL1(__mem__={anchor_id: "B"});
    mem_c = _FakeL1(__mem__={anchor_id: "C"});
    register_l1(id_a, mem_a);
    register_l1(id_b, mem_b);
    register_l1(id_c, mem_c);
    try {
        marked = evict_local_l1(str(anchor_id), id_a);
        assert marked == 2 , f"expected 2 siblings marked, got {marked}";

        assert anchor_id in mem_a.__mem__ , "origin __mem__ must be untouched";
        assert anchor_id in mem_b.__mem__ , "sibling B __mem__ must be untouched";
        assert anchor_id in mem_c.__mem__ , "sibling C __mem__ must be untouched";
        assert not consume_stale(id_a, anchor_id) , "origin must NOT be marked";
        assert consume_stale(id_b, anchor_id) , "sibling B must be marked stale";
        assert consume_stale(id_c, anchor_id) , "sibling C must be marked stale";
        assert not consume_stale(id_b, anchor_id) , "the stale mark must be one-shot";
        assert evict_local_l1("not-a-uuid", id_a) == 0 , "bad id must no-op";
    } finally {
        deregister_l1(id_a);
        deregister_l1(id_b);
        deregister_l1(id_c);
    }
}

test "L1 invalidation: stale-but-clean entries reload, dirty entries survive" {
    import from jaclang.runtimelib.serializer { Serializer }
    import from jaclang.scale.memory.memory_hierarchy { ScaleTieredMemory }
    import from jaclang.scale.memory.l1_invalidation {
        evict_local_l1,
        deregister_l1,
        new_l1_id
    }
    import sys;
    sys.path.insert(0, str(FIXTURES_DIR));
    import from mutation_app { Item }

    os.environ.pop("REDIS_URL", None);
    os.environ.pop("MONGODB_URI", None);

    mem = ScaleTieredMemory();
    mem.l2 = None;
    mem.l3 = None;
    other = new_l1_id();

    clean = Item(id=1).__jac__;
    clean.persistent = True;
    clean.hash = Serializer._compute_hash(clean);

    dirty_item = Item(id=2);
    dirty = dirty_item.__jac__;
    dirty.persistent = True;
    dirty.hash = Serializer._compute_hash(dirty);
    dirty_item.completed = True;

    try {
        for read in ["get", "batch_get", "find_one"] {
            cast(dict, mem.__mem__)[clean.id] = clean;
            cast(dict, mem.__mem__)[dirty.id] = dirty;
            evict_local_l1(str(clean.id), other);
            evict_local_l1(str(dirty.id), other);
            if read == "get" {
                _ = mem.get(clean.id);
                _ = mem.get(dirty.id);
            } elif read == "batch_get" {
                _ = mem.batch_get([clean.id, dirty.id]);
            } else {
                _ = mem.find_one(clean.id);
                _ = mem.find_one(dirty.id);
            }
            assert clean.id not in mem.__mem__ , f"{read}: clean stale entry must drop";
            assert dirty.id in mem.__mem__ , f"{read}: dirty entry must survive";
        }
        assert dirty_item.completed == True , "the uncommitted mutation must survive";
    } finally {
        deregister_l1(mem._l1_id);
    }
}

test "L1 invalidation: GC reclaims the registry and clears stale marks" {
    import gc;
    import from uuid { uuid4 }
    import from jaclang.scale.memory.l1_invalidation {
        register_l1,
        evict_local_l1,
        new_l1_id,
        _l1_registry,
        _stale_marks
    }

    aid = uuid4();
    lid = new_l1_id();
    mem = _FakeL1(__mem__={aid: "x"});
    register_l1(lid, mem);
    evict_local_l1(str(aid), new_l1_id());
    assert lid in _l1_registry , "registered id must be present";
    assert lid in _stale_marks , "mark must be present";
    del mem;
    gc.collect();

    assert lid not in _l1_registry , "weak entry must disappear on GC";
    assert lid not in _stale_marks , "finalizer must clear stale marks on GC";
}

test "L1 invalidation: pub/sub delivers (origin suppressed) and recovers after a drop" {
    import time;
    import from uuid { uuid4 }
    import from jaclang.scale.memory.memory_hierarchy {
        ScaleTieredMemory,
        _process_cache
    }
    import from jaclang.scale.memory.l1_invalidation { stop_listener, consume_stale }

    _reset_redis();
    _reset_process_cache();
    _redis_result = _get_redis();
    redis_client: any = _redis_result[0];
    redis_url: str = cast(str, _redis_result[1]);
    os.environ["REDIS_URL"] = redis_url;
    os.environ.pop("MONGODB_URI", None);

    try {
        mem_a = ScaleTieredMemory();
        mem_b = ScaleTieredMemory();
        assert mem_a.l2 is not None and mem_b.l2 is not None , "Redis L2 required";

        aid1 = uuid4();
        cast(dict, mem_b.__mem__)[aid1] = "x";
        cast(dict, mem_a.__mem__)[aid1] = "x";
        delivered1 = False;
        deadline = time.time() + 5.0;
        while time.time() < deadline and not delivered1 {
            cast(any, mem_a.l2).publish_invalidation(str(aid1), mem_a._l1_id);
            time.sleep(0.05);
            if consume_stale(mem_b._l1_id, aid1) {
                delivered1 = True;
            }
        }
        assert delivered1 , "baseline pub/sub delivery must work";
        assert not consume_stale(mem_a._l1_id, aid1) , "writer's own L1 must not be marked";

        with contextlib.suppress(Exception) {
            redis_client.execute_command("CLIENT", "KILL", "TYPE", "pubsub");
        }
        time.sleep(1.0);

        aid2 = uuid4();
        cast(dict, mem_b.__mem__)[aid2] = "y";
        delivered2 = False;
        deadline = time.time() + 8.0;
        while time.time() < deadline and not delivered2 {
            cast(any, mem_a.l2).publish_invalidation(str(aid2), mem_a._l1_id);
            time.sleep(0.1);
            if consume_stale(mem_b._l1_id, aid2) {
                delivered2 = True;
            }
        }
        assert delivered2 , "delivery must resume after a connection drop";
    } finally {
        stop_listener(_process_cache);
        os.environ.pop("REDIS_URL", None);
        _reset_process_cache();
    }
}

test "L1 invalidation: ensure_listener is idempotent and self-heals" {
    import time;
    import from jaclang.scale.memory.l1_invalidation { ensure_listener, stop_listener }

    _reset_process_cache();
    _redis_result = _get_redis();
    redis_url: str = cast(str, _redis_result[1]);
    cache: dict = {};
    try {
        ensure_listener(cache, redis_url, "jac:test:invalidate");
        first: any = cache.get("l1_listener");
        assert first is not None and first.is_alive() , "listener must start";

        ensure_listener(cache, redis_url, "jac:test:invalidate");
        assert cache.get("l1_listener") is first , (
            "a live listener must be reused, not replaced"
        );

        first.stop();
        first.join(2.0);
        time.sleep(0.1);
        assert not first.is_alive() , "listener must stop on request";
        ensure_listener(cache, redis_url, "jac:test:invalidate");
        second: any = cache.get("l1_listener");
        assert second is not None and second is not first , (
            "a dead listener must be replaced"
        );
        assert second.is_alive() , "replacement listener must be running";

        empty: dict = {};
        ensure_listener(empty, None, "jac:test:invalidate");
        assert "l1_listener" not in empty , "no listener without a redis url";
    } finally {
        stop_listener(cache);
        os.environ.pop("REDIS_URL", None);
        _reset_process_cache();
    }
}


obj _L2CachePerson(Root) {
    has name: str = "";
}


test "RedisBackend loads carry a field-hash snapshot (L2 parity with L3 loads)" {
    import from jaclang.scale.memory.memory_hierarchy { RedisBackend }
    import from jaclang.runtimelib.changeset { derive_dirty_fields }

    _reset_redis();
    (rclient, redis_url) = _get_redis();
    be = RedisBackend(redis_url=cast(str, redis_url));

    person = _L2CachePerson(name="cached").__jac__;
    person.persistent = True;
    be.put(person);

    loaded = be.get(person.id);
    assert loaded is not None , "anchor must round-trip through Redis";
    assert loaded.archetype.__dict__.get('__jac_field_hashes__') , (
        "L2-loaded anchors must carry a field-hash snapshot like L3 loads do; "
        "without one, derive_dirty_fields() is blind for this anchor and the "
        "collect pass can drop its field mutations (or fall back to full "
        "rewrites) for the rest of the request"
    );
    assert derive_dirty_fields(loaded) == set() , (
        "a freshly L2-loaded anchor must derive as clean"
    );
    loaded.archetype.name = "renamed";
    assert derive_dirty_fields(loaded) == {'name'} , (
        "field mutations on an L2-loaded anchor must be derivable"
    );
}
