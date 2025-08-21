"""Test utils."""

from contextlib import suppress
from os import environ, getenv
from subprocess import Popen, run
from time import sleep
from typing import Literal, overload
from unittest import TestCase

from fakeredis import FakeRedis

from httpx import get, post

from pymongo import MongoClient

from redis import Redis as RedisClient

from ..jaseci.datasources import Collection, MontyClient, Redis


class JacCloudTest(TestCase):
    """Test Utils."""

    server: Popen
    host: str
    database: str
    users: list[dict]

    @classmethod
    def run_server(
        cls,
        file: str,
        port: int = 8000,
        database: str = "jaseci",
        envs: dict | None = None,
        wait: int = 10,
    ) -> None:
        """Run server."""
        run(["fuser", "-k", f"{port}/tcp"])

        base_envs = environ.copy()
        base_envs["DATABASE_NAME"] = database

        if envs:
            base_envs.update(envs)

        cls.server = Popen(
            ["jac", "serve", f"{file}", "--port", f"{port}"], env=base_envs
        )

        cls.host = f"http://localhost:{port}"
        cls.database = database
        cls.users = []

        count = 0
        while True:
            if count > wait:
                cls.check_server()
                break
            else:
                with suppress(Exception):
                    cls.check_server()
                    break
                sleep(1)
            count += 1

    @classmethod
    def stop_server(cls) -> None:
        """Stop server."""
        cls.server.kill()

    @classmethod
    def check_server(cls) -> None:
        """Retrieve OpenAPI Specs JSON."""
        res = get(f"{cls.host}/healthz")
        res.raise_for_status()
        assert res.status_code == 200

        if getenv("DATABASE_HOST"):
            assert isinstance(Collection.get_client(), MongoClient)
        else:
            assert isinstance(Collection.get_client(), MontyClient)

        if getenv("REDIS_HOST"):
            assert isinstance(Redis.get_rd(), RedisClient)
        else:
            assert isinstance(Redis.get_rd(), FakeRedis)

    @overload
    def post_api(self, api: str, json: dict | None = None, user: int = 0) -> dict:
        pass

    @overload
    def post_api(
        self,
        api: str,
        json: dict | None = None,
        user: int = 0,
        expect_error: Literal[True] = True,
    ) -> int:
        pass

    def post_api(
        self,
        api: str,
        json: dict | None = None,
        user: int = 0,
        expect_error: bool = False,
    ) -> dict | int:
        """Call walker post API."""
        res = post(
            f"{self.host}/walker/{api}", json=json, headers=self.users[user]["headers"]
        )

        if not expect_error:
            res.raise_for_status()
            return res.json()
        else:
            return res.status_code

    def post_webhook(
        self, api: str, json: dict | None = None, headers: dict | None = None
    ) -> dict:
        """Call walker post API."""
        res = post(f"{self.host}/webhook/walker/{api}", json=json, headers=headers)

        res.raise_for_status()
        return res.json()
