"""Test utils."""

from contextlib import suppress
from os import makedirs, rmdir, unlink
from pathlib import Path
from subprocess import Popen, run
from time import sleep
from unittest import TestCase

from httpx import get

from yaml import safe_load


class HotReloadTest(TestCase):
    """Test Utils."""

    def test_hot_reload(self) -> None:
        """Run server."""
        run(["fuser", "-k", "8001/tcp"])
        self.directory = Path(__file__).parent
        open(f"{self.directory}/test.jac", "w").close()
        server = Popen(
            [
                "jac",
                "serve",
                f"{self.directory}/test.jac",
                "--port",
                "8001",
                "--reload",
            ]
        )

        try:
            self.host = "http://localhost:8001"

            self.check_server_loop()

            res = get(f"{self.host}/openapi.yaml", verify=False, timeout=1)
            res.raise_for_status()
            with open(f"{self.directory}/clean_openapi_specs.yaml") as file:
                self.assertEqual(safe_load(file), safe_load(res.text))

            res = get(f"{self.host}/walker/public")
            self.assertEqual(404, res.status_code)

            self.write_code()

            self.trigger_public_loop()

            res = get(f"{self.host}/openapi.yaml", verify=False, timeout=1)
            res.raise_for_status()
            with open(f"{self.directory}/clean_openapi_specs.yaml") as file:
                self.assertNotEqual(safe_load(file), safe_load(res.text))
        finally:
            server.kill()
            unlink(f"{self.directory}/test.jac")
            run(["fuser", "-k", "8001/tcp"])

    def test_hot_reload_with_watch(self) -> None:
        """Run server."""
        run(["fuser", "-k", "8001/tcp"])
        self.directory = Path(__file__).parent

        makedirs(f"{self.directory}/dir")
        open(f"{self.directory}/test.jac", "w").close()
        server = Popen(
            [
                "jac",
                "serve",
                f"{self.directory}/test.jac",
                "--port",
                "8001",
                "--reload",
                "--watch",
                f"{self.directory}/dir",
            ]
        )

        try:
            self.host = "http://localhost:8001"

            self.check_server_loop()

            res = get(f"{self.host}/openapi.yaml", verify=False, timeout=1)
            res.raise_for_status()
            with open(f"{self.directory}/clean_openapi_specs.yaml") as file:
                self.assertEqual(safe_load(file), safe_load(res.text))

            res = get(f"{self.host}/walker/public")
            self.assertEqual(404, res.status_code)

            self.write_code()

            self.check_server_loop()

            res = get(f"{self.host}/walker/public")
            self.assertEqual(404, res.status_code)

            open(f"{self.directory}/dir/test.jac", "w").close()

            self.trigger_public_loop()

            res = get(f"{self.host}/openapi.yaml", verify=False, timeout=1)
            res.raise_for_status()
            with open(f"{self.directory}/clean_openapi_specs.yaml") as file:
                self.assertNotEqual(safe_load(file), safe_load(res.text))
        finally:
            server.kill()
            unlink(f"{self.directory}/test.jac")
            unlink(f"{self.directory}/dir/test.jac")
            rmdir(f"{self.directory}/dir")
            run(["fuser", "-k", "8001/tcp"])

    def check_server_loop(self) -> None:
        """Check server test."""
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

    def check_server(self) -> None:
        """Retrieve OpenAPI Specs JSON."""
        res = get(f"{self.host}/healthz", verify=False)
        res.raise_for_status()
        self.assertEqual(200, res.status_code)

    def write_code(self) -> None:
        """Write jac code."""
        with open(f"{self.directory}/test.jac", "w") as code:
            code.write(
                """
walker public {
    class __specs__ {
        static has methods: str = ["get"], auth: bool = False;
    }

    can enter with `root entry {
        report 1;
    }
}
"""
            )

    def trigger_public_loop(self) -> None:
        """Check server test."""
        count = 0
        while True:
            if count > 5:
                self.trigger_public()
                break
            else:
                with suppress(Exception):
                    self.trigger_public()
                    break
                sleep(1)
            count += 1

    def trigger_public(self) -> None:
        """Trigger public api."""
        res = get(f"{self.host}/walker/public")
        res.raise_for_status()
        self.assertEqual({"status": 200, "reports": [1]}, res.json())
