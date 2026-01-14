import contextlib
import gc
import os
import socket
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, cast

import redis
import requests
from pymongo import MongoClient
from testcontainers.mongodb import MongoDbContainer
from testcontainers.redis import RedisContainer


def get_free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("", 0))
        return s.getsockname()[1]


class TestMemoryHierarchy:
    fixtures_dir: Path
    jac_file: Path
    base_url: str
    port: int

    redis_client: redis.Redis
    mongo_client: MongoClient

    redis_container: RedisContainer
    mongo_container: MongoDbContainer
    server: subprocess.Popen[str] | None = None

    @classmethod
    def setup_class(cls) -> None:
        cls.fixtures_dir = Path(__file__).parent / "fixtures"
        cls.jac_file = cls.fixtures_dir / "todo_app.jac"

        if not cls.jac_file.exists():
            raise FileNotFoundError(f"Missing Jac file: {cls.jac_file}")

        # Clean up session file from previous runs to ensure test isolation
        session_file = (
            cls.fixtures_dir / ".jac" / "data" / "todo_app.session.users.json"
        )
        if session_file.exists():
            os.remove(session_file)

        # start redis container
        cls.redis_container = RedisContainer("redis:latest", port=6379)
        cls.redis_container.start()

        redis_host = cls.redis_container.get_container_host_ip()
        redis_port = cls.redis_container.get_exposed_port(6379)

        redis_url = f"redis://{redis_host}:{redis_port}/0"

        cls.redis_client = redis.Redis(
            host=redis_host, port=int(redis_port), decode_responses=False
        )

        # here we are verifying that redis is empty before starting tests
        assert cls.redis_client.dbsize() == 0

        # start mongo container
        cls.mongo_container = MongoDbContainer("mongo:latest")
        cls.mongo_container.start()

        mongo_uri = cls.mongo_container.get_connection_url()
        cls.mongo_client = MongoClient(mongo_uri)

        os.environ["MONGODB_URI"] = mongo_uri
        os.environ["REDIS_URL"] = redis_url

        assert "jac_db" not in cls.mongo_client.list_database_names()

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
        # Clean up session file from .jac/data directory
        session_file = (
            cls.fixtures_dir / ".jac" / "data" / "todo_app.session.users.json"
        )
        if session_file.exists():
            os.remove(session_file)

    @classmethod
    def _start_server(cls) -> None:
        # Get the jac executable from the same directory as the current Python interpreter
        jac_executable = Path(sys.executable).parent / "jac"
        cmd = [
            str(jac_executable),
            "start",
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
            f"jac start failed to start\nSTDOUT:\n{stdout}\nSTDERR:\n{stderr}"
        )

    @staticmethod
    def _extract_transport_response_data(
        json_response: dict[str, Any] | list[Any],
    ) -> dict[str, Any] | list[Any]:
        """Extract data from TransportResponse envelope format."""
        # Handle jac-scale's tuple response format [status, body]
        if isinstance(json_response, list) and len(json_response) == 2:
            body: dict[str, Any] = json_response[1]
            json_response = body

        # Handle TransportResponse envelope format
        if (
            isinstance(json_response, dict)
            and "ok" in json_response
            and "data" in json_response
        ):
            if json_response.get("ok") and json_response.get("data") is not None:
                # Success case: return the data field
                return json_response["data"]
            elif not json_response.get("ok") and json_response.get("error"):
                # Error case: return error info
                error_info = json_response["error"]
                result: dict[str, Any] = {
                    "error": error_info.get("message", "Unknown error")
                }
                if "code" in error_info:
                    result["error_code"] = error_info["code"]
                if "details" in error_info:
                    result["error_details"] = error_info["details"]
                return result
        # FastAPI validation errors (422) have "detail" field - return as-is
        return json_response

    def _register(self, username: str, password: str = "password123") -> str:
        res = requests.post(
            f"{self.base_url}/user/register",
            json={"username": username, "password": password},
            timeout=5,
        )
        assert res.status_code == 201, (
            f"Registration failed: {res.status_code} - {res.text}"
        )
        data = cast(dict[str, Any], self._extract_transport_response_data(res.json()))
        return data["token"]

    def _post(self, path: str, payload: dict, token: str) -> dict[str, Any]:
        res = requests.post(
            f"{self.base_url}{path}",
            json=payload,
            headers={"Authorization": f"Bearer {token}"},
            timeout=5,
        )
        assert res.status_code == 200
        return cast(dict[str, Any], self._extract_transport_response_data(res.json()))

    # TODO: delete method in jac start is not working as expected. will be fixed in a separate PR and a test case will be added

    def test_read_and_write(self) -> None:
        db = self.mongo_client["jac_db"]
        collection = db["anchors"]

        mongo_doc_initial_count = collection.count_documents({})
        assert (
            mongo_doc_initial_count == 2
        )  # the initial docs is two, because super root, guest_user

        # Register a user
        token = self._register("reader", "pass123")

        mongo_doc_after_user_creation_count = collection.count_documents({})
        assert (
            mongo_doc_after_user_creation_count == 3
        )  # the initial docs is three, because super root, guest_user and the created user

        redis_size_before_task_creation = self.redis_client.dbsize()

        # Create tasks
        created_tasks = [
            {"id": 203, "title": "Task 203"},
            {"id": 204, "title": "Task 204"},
        ]

        redis_size_after_task_creation = self.redis_client.dbsize()

        for task_payload in created_tasks:
            self._post("/walker/CreateTask", task_payload, token)

        mongo_doc_count_after_task_creation = collection.count_documents({})

        assert (
            mongo_doc_count_after_task_creation == 7
        )  # the previous 3 and two anchors (1 node + 1 edge) for each task

        assert redis_size_after_task_creation == redis_size_before_task_creation

        self._post("/walker/GetAllTasks", {}, token)

        redis_size_after_task_read = self.redis_client.dbsize()

        assert (
            redis_size_after_task_read == 7
        )  # super root, guest user, created user, two task nodes, and two edges
