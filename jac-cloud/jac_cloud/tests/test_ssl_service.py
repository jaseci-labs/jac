"""Test utils."""

from contextlib import suppress
from os import environ
from pathlib import Path
from subprocess import Popen, run
from time import sleep
from unittest import TestCase

from httpx import get

from yaml import safe_load


class SSLServiceTest(TestCase):
    """Test Utils."""

    def test_ssl_service(self) -> None:
        """Run server."""
        run(["fuser", "-k", "8443/tcp"])

        self.directory = Path(__file__).parent

        env = environ.copy()
        env["UV_SSL_CERTFILE"] = f"{self.directory}/localhost.crt"
        env["UV_SSL_KEYFILE"] = f"{self.directory}/localhost.key"

        self.server = Popen(
            ["jac", "serve", f"{self.directory}/simple_graph.jac", "--port", "8443"],
            env=env,
        )

        self.host = "https://localhost:8443"

        count = 0
        while True:
            if count > 10:
                self.check_server()
                break
            else:
                with suppress(Exception):
                    self.check_server()
                    break
                sleep(1)
            count += 1

        res = get(f"{self.host}/openapi.yaml", verify=False, timeout=1)
        res.raise_for_status()

        with open(f"{self.directory}/openapi_specs.yaml") as file:
            self.assertEqual(safe_load(file), safe_load(res.text))

        self.server.kill()

    def check_server(self) -> None:
        """Retrieve OpenAPI Specs JSON."""
        res = get(f"{self.host}/healthz", verify=False)
        res.raise_for_status()
        self.assertEqual(200, res.status_code)
