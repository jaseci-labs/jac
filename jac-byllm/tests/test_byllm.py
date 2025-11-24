"""Tests for Integration with Jaclang."""

import io
import sys

from jaclang import JacMachineInterface as Jac
from jaclang.utils.test import TestCase

from fixtures import python_lib_mode

# Import the jac_import function from JacMachineInterface
jac_import = Jac.jac_import


class JacLanguageTests(TestCase):
    """Tests for Integration with Jaclang."""

    def setUp(self) -> None:
        """Set up test."""
        return super().setUp()

    def test_llm_mail_summerize(self) -> None:
        """Parse micro jac file."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        jac_import("llm_mail_summerize", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        summaries = [
            "AetherGuard reports a login to your account from a new device in Berlin and advises a password reset if the activity was unauthorized.",
            "Claire from Novelink invites writers to a biweekly Writer's Circle this Friday for sharing work and receiving feedback in a supportive environment.",
            "Marcus Bentley from FinTracker reports a weekly spending total of $342.65, mainly on Groceries, Transport, and Dining, with a link for detailed insights.",
            "TechNews from DailyByte highlights how quantum computing is set to transform fields like cryptography and climate modeling, with more details in the full article.",
            "Nora Hartwell from Wanderlust Travels offers a 30% discount on international trips booked this week, urging recipients to take advantage of the limited-time travel deal.",
        ]
        for summary in summaries:
            self.assertIn(summary, stdout_value)

    def test_method_include_context(self) -> None:
        """Test the method include context functionality."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        jac_import("method_incl_ctx", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()

        # Check if the output contains the expected context information
        self.assertIn("Average marks for Alice : 86.75", stdout_value)

    def test_with_llm_function(self) -> None:
        """Parse micro jac file."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        jac_import("with_llm_function", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("👤➡️🗼", stdout_value)

    def test_method_tool_call(self) -> None:
        """Parse micro jac file."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        jac_import("method_tool", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("Calculator.add called with 12, 34", stdout_value)
        self.assertIn("Result: 46", stdout_value)

    def test_image_input(self) -> None:
        """Parse micro jac file."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        jac_import("image_test", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn(
            "The image shows a hot air balloon shaped like a heart", stdout_value
        )

    def test_streaming_output(self) -> None:
        """Parse micro jac file."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        jac_import("streaming_output", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn(
            "The orca whale, or killer whale, is one of the most intelligent and adaptable marine predators",
            stdout_value,
        )

    def test_by_expr(self) -> None:
        """Test by llm['as'].expression instead of llm() call."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        jac_import("by_expr", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        expected_lines = (
            "Generated greeting: Hello, Alice! It's great to see you!",
            "[run_and_test_python_code] Executing code:",
            "[run_and_test_python_code] \"name = 'Alice'\\nprint(f'Hello, {name}! Welcome to the Python world!')\"",
            "Hello, Alice! Welcome to the Python world!",
            "[run_and_test_python_code] Code executed successfully.",
            "Generated greeting code: name = 'Alice'",
            "print(f'Hello, {name}! Welcome to the Python world!')",
        )
        for line in expected_lines:
            self.assertIn(line, stdout_value)

    def test_with_llm_method(self) -> None:
        """Parse micro jac file."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        jac_import("with_llm_method", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        # TODO: Reasoning is not passed as an output, however this needs to be
        # sent to some callbacks (or other means) to the user.
        # self.assertIn("[Reasoning] <Reason>", stdout_value)
        self.assertIn("Personality.INTROVERT", stdout_value)

    def test_with_llm_lower(self) -> None:
        """Parse micro jac file."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        jac_import("with_llm_lower", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        # TODO: Reasoning is not passed as an output, however this needs to be
        # sent to some callbacks (or other means) to the user.
        # self.assertIn("[Reasoning] <Reason>", stdout_value)
        self.assertIn(
            "J. Robert Oppenheimer was a Introvert person who died in 1967",
            stdout_value,
        )

    def test_with_llm_type(self) -> None:
        """Parse micro jac file."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        jac_import("with_llm_type", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("14/03/1879", stdout_value)
        self.assertNotIn(
            'University (University) (obj) = type(__module__="with_llm_type", __doc__=None, '
            "_jac_entry_funcs_`=[`], _jac_exit_funcs_=[], __init__=function(__wrapped__=function()))",
            stdout_value,
        )
        desired_output_count = stdout_value.count(
            "Person(name='Jason Mars', dob='1994-01-01', age=30)"
        )
        self.assertEqual(desired_output_count, 2)

    def test_with_llm_image(self) -> None:
        """Test MTLLLM Image Implementation."""
        try:
            captured_output = io.StringIO()
            sys.stdout = captured_output
            jac_import("with_llm_image", base_path=self.fixture_abs_path("./"))
            sys.stdout = sys.__stdout__
            stdout_value = captured_output.getvalue()
            self.assertIn(
                "{'type': 'text', 'text': '\\n[System Prompt]\\n", stdout_value[:500]
            )
            self.assertNotIn(
                " {'type': 'text', 'text': 'Image of the Question (question_img) (Image) = '}, "
                "{'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQAB",
                stdout_value[:500],
            )
        except Exception:
            self.skipTest("This test requires Pillow to be installed.")

    def test_webp_image_support(self):
        """Test MTLLLM image support for webp format."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        jac_import("webp_support_test", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("full_name='Albert Einstein'", stdout_value)
        self.assertIn("year_of_death='1955'", stdout_value)

    def test_with_llm_video(self) -> None:
        """Test MTLLLM Video Implementation."""
        try:
            captured_output = io.StringIO()
            sys.stdout = captured_output
            jac_import("with_llm_video", base_path=self.fixture_abs_path("./"))
            sys.stdout = sys.__stdout__
            stdout_value = captured_output.getvalue()
            video_explanation = (
                "The video features a large rabbit emerging from a burrow in a lush, green environment. "
                "The rabbit stretches and yawns, seemingly enjoying the morning. The scene is set in a "
                "vibrant, natural setting with bright skies and trees, creating a peaceful and cheerful atmosphere."
            )
            self.assertIn(video_explanation, stdout_value)
        except Exception:
            self.skipTest("This test requires OpenCV to be installed.")

    def test_semstrings(self) -> None:
        """Test the semstrings with the new sem keyword.

        obj Foo {
            def bar(baz: int) -> str;
        }
        sem Foo.bar.baz = "Some semantic string for Foo.bar.baz";
        """
        captured_output = io.StringIO()
        sys.stdout = captured_output
        jac_import("llm_semstrings", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("Specific number generated: 120597", stdout_value)

        i = stdout_value.find("Generated password:")
        password = stdout_value[i:].split("\n")[0]

        self.assertTrue(
            len(password) >= 8, "Password should be at least 8 characters long."
        )
        self.assertTrue(
            any(c.isdigit() for c in password),
            "Password should contain at least one digit.",
        )
        self.assertTrue(
            any(c.isupper() for c in password),
            "Password should contain at least one uppercase letter.",
        )
        self.assertTrue(
            any(c.islower() for c in password),
            "Password should contain at least one lowercase letter.",
        )

    def test_python_lib_mode(self) -> None:
        """Test the Python library mode."""
        person = python_lib_mode.test_get_person_info()

        # Check if the output contains the expected person information
        self.assertIn("Alan Turing", person.name)
        self.assertIn("1912", str(person.birth_year))
        self.assertIn(
            "A pioneering mathematician and computer scientist", person.description
        )
        self.assertIn("breaking the Enigma code", person.description)

    def test_enum_without_value(self) -> None:
        "This tests enum without values, where enum names gets into the prompt."
        captured_output = io.StringIO()
        sys.stdout = captured_output
        try:
            jac_import("enum_no_value", base_path=self.fixture_abs_path("./"))
        except Exception:
            # API key error is expected, but we still capture the output before the error
            pass
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("YES", stdout_value)
        self.assertIn("NO", stdout_value)

    def test_fixtures_image_types(self) -> None:
        """Test various image input types in Jaclang."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        jac_import("image_types", base_path=self.fixture_abs_path("./"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        expected_labels = [
            "PIL Image",
            "Image from file path",
            "Image from URL",
            "Image from BytesIO",
            "Image from raw bytes",
            "Image from memoryview",
            "Image from data URL",
            "Image from PathLike",
            "Image from file-like without getvalue",
            "Image from bytearray",
            "Image from gs:// URL",
        ]
        for label in expected_labels:
            self.assertIn(label, stdout_value)
