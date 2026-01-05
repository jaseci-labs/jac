import contextlib
import gc
import os
import pickle
import socket
import subprocess
import time
from pathlib import Path

import redis
import requests
from pymongo import MongoClient
import contextlib
import time
import gc
import requests
import os
import pickle

from testcontainers.redis import RedisContainer
from testcontainers.mongodb import MongoDbContainer


def get_free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("", 0))
        return s.getsockname()[1]


class TestMemoryHierarchy:
    fixtures_dir: Path
    jac_file: Path
    base_url: str
    port: int

    redis_container: RedisContainer
    mongo_container: MongoDbContainer
    server: subprocess.Popen[str] | None = None

    @classmethod
    def setup_class(cls) -> None:
        cls.fixtures_dir = Path(__file__).parent / "fixtures"
        cls.jac_file = cls.fixtures_dir / "todo_app.jac"

        if not cls.jac_file.exists():
            raise FileNotFoundError(f"Missing Jac file: {cls.jac_file}")

        # start redis container
        cls.redis_container = RedisContainer("redis:latest", port=6379)
        cls.redis_container.start()

        redis_host = cls.redis_container.get_container_host_ip()
        redis_port = cls.redis_container.get_exposed_port(6379)

        redis_url = f"redis://{redis_host}:{redis_port}/0"

        cls.redis_client = redis.Redis(
            host=redis_host, port=int(redis_port), decode_responses=False
        )
        print(f"redis db size: {cls.redis_client.dbsize()}")

        # here we are verifying that redis is empty before starting tests
        assert cls.redis_client.dbsize() == 0

        # start mongo container
        cls.mongo_container = MongoDbContainer("mongo:latest")
        cls.mongo_container.start()

        mongo_uri = cls.mongo_container.get_connection_url()
        cls.mongo_client = MongoClient(mongo_uri)

        os.environ["mongodb_uri"] = mongo_uri
        os.environ["redis_url"] = redis_url

        # verify there are no additional mongo dbs
        system_dbs = {"admin", "config", "local"}

        initial_dbs = set(cls.mongo_client.list_database_names()) - system_dbs
        assert not initial_dbs, "there exists other databases in the initial stage"

        # setting up
        cls.port = get_free_port()
        cls.base_url = f"http://localhost:{cls.port}"

        cls._start_server()

    @classmethod
    def teardown_class(cls) -> None:
        if cls.server:
            cls.server.terminate()
            with contextlib.suppress(Exception):
                cls.server.wait(timeout=5)

        system_dbs = {"admin", "config", "local"}
        for db_name in cls.mongo_client.list_database_names():
            if db_name not in system_dbs:
                cls.mongo_client.drop_database(db_name)

        cls.mongo_container.stop()
        cls.redis_container.stop()

        time.sleep(0.5)
        gc.collect()

    @classmethod
    def _start_server(cls) -> None:
        cmd = [
            "jac",
            "serve",
            str(cls.jac_file.name),
            "--port",
            str(cls.port),
        ]

        env = os.environ.copy()

        cls.server = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            cwd=str(cls.fixtures_dir),
            env=env,
        )

        for _ in range(30):
            try:
                r = requests.get(f"{cls.base_url}/docs", timeout=1)
                if r.status_code in (200, 404):
                    return
            except Exception:
                time.sleep(1)

        stdout, stderr = cls.server.communicate(timeout=2)
        raise RuntimeError(
            f"jac serve failed to start\nSTDOUT:\n{stdout}\nSTDERR:\n{stderr}"
        )

    def _register(self, username: str, password: str = "password123") -> str:
        res = requests.post(
            f"{self.base_url}/user/register",
            json={"username": username, "password": password},
            timeout=5,
        )
        assert res.status_code == 201
        return res.json()["token"]

    def _post(self, path: str, payload: dict, token: str) -> dict:
        res = requests.post(
            f"{self.base_url}{path}",
            json=payload,
            headers={"Authorization": f"Bearer {token}"},
            timeout=5,
        )
        assert res.status_code == 200
        return res.json()

    def _redis_snapshot(self) -> set[str]:
        return set(self.redis_client.keys("anchor:*"))

    def _redis_contains_task(self) -> bool:
        for key in self.redis_client.keys("anchor:*"):
            raw = self.redis_client.get(key)
            try:
                obj = pickle.loads(raw)
                print(obj.archetype.__class__.__name__)
                if obj.archetype.__class__.__name__ == "Task":
                    return True
            except Exception:
                pass
        return False

    def test_write(self) -> None:
        token = self._register("akindu", "pass123")

        system_dbs = {"admin", "config", "local"}

        # create tasks
        self._post("/walker/CreateTask", {"id": 1, "title": "Task 1"}, token)

        self._post("/walker/CreateTask", {"id": 2, "title": "Task 2"}, token)

        # checking whether new data bases are created
        current_dbs = set(self.mongo_client.list_database_names())
        new_user_dbs = current_dbs - system_dbs

        assert new_user_dbs, "user dbs are not created"
        assert len(current_dbs) > len(system_dbs)

        assert not self._redis_contains_task(), "Task objects leaked into Redis"

        self._post("/walker/DeleteTask", {"id": 1}, token)

        self._post("/walker/DeleteTask", {"id": 2}, token)

    def test_read(self) -> None:
        # Register a user
        token = self._register("reader", "pass123")

        # Create tasks
        created_tasks = [
            {"id": 203, "title": "Task 203"},
            {"id": 204, "title": "Task 204"},
        ]

        for task_payload in created_tasks:
            self._post("/walker/CreateTask", task_payload, token)
