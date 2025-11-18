"""Test Jac-cloud cli module."""

import os
import signal
import subprocess
import time
from jaclang.utils.test import TestCase


class JacCloudCliTests(TestCase):
    """Test Jac-cloud cli module."""

    def setUp(self) -> None:
        """Set up test."""
        return super().setUp()

    def test_jac_run_serve(self) -> None:
        """Test a specific test case."""
        run = subprocess.Popen(
            [
                "jac",
                "run",
                self.fixture_abs_path("jac_run_serve.jac"),
            ],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        run_out, _ = run.communicate()
        self.assertIn(
            "It will be executed during jac run and will not be executed during jac serve",
            run_out,
        )

        serve = subprocess.Popen(
            [
                "jac",
                "serve",
                self.fixture_abs_path("jac_serve.jac"),
            ],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            start_new_session=True,
            bufsize=1,
        )
        time.sleep(2)
        os.killpg(serve.pid, signal.SIGTERM)
        try:
            serve_out, _ = serve.communicate(timeout=10)
        except subprocess.TimeoutExpired:
            os.killpg(serve.pid, signal.SIGKILL)
            serve_out, _ = serve.communicate()
        self.assertNotIn(
            "It will be executed during jac run and will not be executed during jac serve",
            serve_out,
        )
