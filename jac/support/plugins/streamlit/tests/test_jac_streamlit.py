"""Test Jac Plugins."""

import os
import subprocess
from pathlib import Path


from jaclang.utils.test import TestCase

from jaclang_streamlit import AppTest


class JacStreamlitPlugin(TestCase):
    """Test pass module."""

    def setUp(self) -> None:
        """Set up test."""
        return super().setUp()

    def test_streamlit(self) -> None:
        """Basic test for pass."""
        command_streamlit = "jac streamlit -h"
        command_dot_view = "jac dot_view -h"

        env = os.environ.copy()
        plugin_root = Path(__file__).resolve().parents[1]
        project_root = Path(__file__).resolve().parents[4]
        env["PYTHONPATH"] = os.pathsep.join(
            [str(plugin_root), str(project_root), env.get("PYTHONPATH", "")]
        )

        result = subprocess.run(
            command_streamlit, shell=True, capture_output=True, text=True, env=env
        )
        dot_result = subprocess.run(
            command_dot_view, shell=True, capture_output=True, text=True, env=env
        )

        # Check basic description
        self.assertIn("Streamlit the specified .jac file", result.stdout)

        # Check CLI structure
        self.assertIn("positional arguments:", result.stdout)
        self.assertIn("filename", result.stdout)

        # Dot view command
        self.assertIn("View the content of a DOT file", dot_result.stdout)
        self.assertIn("positional arguments:", dot_result.stdout)
        self.assertIn("filename", dot_result.stdout)

    def test_app(self) -> None:
        """Test Jac Streamlit App."""
        fixture_abs_path = self.fixture_abs_path("sample.jac")
        app: AppTest = AppTest.from_jac_file(fixture_abs_path).run()
        self.assertEqual(len(app.exception), 0)
        self.assertEqual(app.get("button")[0].label, "Greet me")

        app.get("text_input")[0].set_value("John Doe")
        app.get("number_input")[0].set_value(42)
        app.get("button")[0].set_value(True).run()
        self.assertEqual(app.success[0].value, "Hello, John Doe! You are 42 years old.")
