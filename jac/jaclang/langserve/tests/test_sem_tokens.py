"""Test Semantic Tokens Update."""

import copy
import lsprotocol.types as lspt
from jaclang import JacMachineInterface as _
from jaclang.utils.test import TestCase
from jaclang.langserve.sem_manager import SemTokManager

from typing import Tuple


class TestUpdateSemTokens(TestCase):
    """Test update semantic tokens"""

    def setUp(self) -> None:
        """Set up test."""
        # fmt: off
        self.initial_sem_tokens = [
            1, 10, 4, 0, 2, 3, 4, 14, 12, 1, 0, 15, 6, 7, 1, 0, 8, 5, 2, 1,
            0, 10, 5, 2, 1, 1, 11, 4, 0, 2, 0, 10, 6, 7, 1, 0, 9, 6, 7, 1
        ]
        # fmt: on

        self.document_lines = [
            "",
            "import math;",
            "",
            '"""Function to calculate the area of a circle."""',
            "can calculate_area(radius: float) -> float {",
            "    return math.pi * radius * radius;",
            "}",
            " ",
        ]

    def check_semantic_token_update(self, case: Tuple, expected_output: str) -> None:
        """Check semantic token update."""
        doc_lines = copy.deepcopy(self.document_lines)

        updated_semtokens = SemTokManager.update_sem_tokens(
            "circle_ir",
            lspt.DidChangeTextDocumentParams(
                text_document=lspt.VersionedTextDocumentIdentifier(
                    version=32,
                    uri="...jaclang/examples/manual_code/circle.jac",
                ),
                content_changes=[
                    lspt.TextDocumentContentChangeEvent_Type1(
                        range=lspt.Range(start=case[0], end=case[1]),
                        text=case[2],
                        range_length=case[3],
                    )
                ],
            ),
            sem_tokens=copy.deepcopy(self.initial_sem_tokens),
            document_lines=doc_lines,
        )
        self.assertIn(
            expected_output, str(updated_semtokens), f"\nFailed for case: {case[4]}"
        )

    def test_multiline_before_first_token(self) -> None:
        """Test multiline before first token."""
        case = (
            lspt.Position(line=0, character=0),
            lspt.Position(line=0, character=0),
            "\n",
            0,
            "Multiline before first token (Basic)",
        )
        self.document_lines.insert(1, "")
        self.check_semantic_token_update(case, "2, 10, 4, 0, 2, 3, 4, 14,")

    def test_multiline_between_tokens(self) -> None:
        """Test multiline between tokens."""
        case = (
            lspt.Position(line=5, character=19),
            lspt.Position(line=5, character=19),
            "\n    ",
            0,
            "Multiline between tokens (Basic)",
        )
        self.document_lines[5] = "    return math.pi "
        self.document_lines.insert(6, "    * radius * radius;")
        self.check_semantic_token_update(case, "2, 1, 6, 6, 7, 1, ")

    def test_multiline_at_end_of_line(self) -> None:
        """Test multiline at end of line."""
        case = (
            lspt.Position(line=4, character=37),
            lspt.Position(line=4, character=37),
            "\n",
            0,
            "Multiline at end of line",
        )
        self.document_lines[4] = "can calculate_area(radius: float) -> "
        self.document_lines.insert(5, "float {")
        self.check_semantic_token_update(case, " 2, 1, 1, 0, 5, 2, 1, ")

    def test_sameline_space_between_tokens(self) -> None:
        """Test sameline space between tokens."""
        case = (
            lspt.Position(line=5, character=20),
            lspt.Position(line=5, character=20),
            " ",
            0,
            "Sameline space between tokens (Basic)",
        )
        self.check_semantic_token_update(case, "0, 11, 6, 7, 1,")

    def test_sameline_tab_between_tokens(self) -> None:
        """Test sameline tab between tokens."""
        case = (
            lspt.Position(line=5, character=20),
            lspt.Position(line=5, character=20),
            "    ",
            0,
            "Sameline tab between tokens (Basic)",
        )
        self.check_semantic_token_update(case, "0, 14, 6, 7, 1")

    def test_tab_at_start_of_token(self) -> None:
        """Test tab at start of token."""
        case = (
            lspt.Position(line=5, character=21),
            lspt.Position(line=5, character=21),
            "   ",
            0,
            "Tab at start of a token",
        )
        self.check_semantic_token_update(case, "0, 13, 6, 7, 1,")

    def test_insert_inside_token(self) -> None:
        """Test insert inside token."""
        case = (
            lspt.Position(line=5, character=13),
            lspt.Position(line=5, character=13),
            "calculate",
            0,
            "insert inside a token",
        )
        self.check_semantic_token_update(case, "1, 11, 13, 0, 2, 0, 19, 6, 7, 1")

    def test_insert_inside_token_selected_range(self) -> None:
        """Test insert inside token selected range."""
        case = (
            lspt.Position(line=5, character=12),
            lspt.Position(line=5, character=14),
            "calculate",
            2,
            "insert inside a token in a selected range",
        )
        self.check_semantic_token_update(case, "1, 11, 11, 0, 2, 0, 17, 6, 7, 1,")

    def test_newline_at_start_of_token(self) -> None:
        """Test newline at start of token."""
        case = (
            lspt.Position(line=5, character=21),
            lspt.Position(line=5, character=21),
            "\n    ",
            0,
            "Newline at start of a token",
        )
        self.document_lines[5] = "    return math.pi * "
        self.document_lines.insert(6, "    radius * radius;")
        self.check_semantic_token_update(case, "0, 2, 1, 4, 6, 7, 1, 0")

    def test_newline_after_parenthesis(self) -> None:
        """Test newline after parenthesis."""
        case = (
            lspt.Position(line=4, character=19),
            lspt.Position(line=4, character=19),
            "\n    ",
            0,
            "Newline after parenthesis",
        )
        self.document_lines[4] = "can calculate_area("
        self.document_lines.insert(5, "    radius: float) -> float {")
        self.check_semantic_token_update(case, "12, 1, 1, 4, 6, 7, 1, 0, 8")

    def test_insert_newline_at_end_of_token(self) -> None:
        """Test insert newline at end of token."""
        case = (
            lspt.Position(line=5, character=27),
            lspt.Position(line=5, character=27),
            "\n    ",
            0,
            "Insert Newline at end of a token",
        )
        self.document_lines[5] = "    return math.pi * radius"
        self.document_lines.insert(6, "     * radius;")
        self.check_semantic_token_update(case, "7, 1, 1, 7, 6, 7")

    def test_deletion_basic(self) -> None:
        """Test deletion basic."""
        case = (
            lspt.Position(line=5, character=4),
            lspt.Position(line=5, character=4),
            "",
            4,
            "Deletion Basic",
        )
        self.check_semantic_token_update(case, "0, 10, 5, 2, 1, 1, 7, 4, 0, 2, 0")

    def test_multiline_deletion(self) -> None:
        """Test multiline deletion."""
        case = (
            lspt.Position(line=3, character=49),
            lspt.Position(line=4, character=0),
            "",
            4,
            "Multiline Deletion",
        )
        self.document_lines[3] = (
            '"""Function to calculate the area of a circle."""can calculate_area(radius: float) -> float {'
        )
        del self.document_lines[4]
        self.check_semantic_token_update(case, "2, 2, 53, 14, 12, 1, 0")

    def test_single_deletion_inside_token(self) -> None:
        """Test single deletion inside token."""
        case = (
            lspt.Position(line=5, character=12),
            lspt.Position(line=5, character=13),
            "",
            1,
            "single Deletion inside token",
        )
        self.check_semantic_token_update(case, "1, 1, 11, 3, 0, 2, 0, 9, 6")

    def test_deletion_inside_token_selected_range(self) -> None:
        """Test deletion inside token selected range."""
        case = (
            lspt.Position(line=4, character=10),
            lspt.Position(line=4, character=15),
            "",
            5,
            "Deletion inside token- selected range",
        )
        self.check_semantic_token_update(case, "4, 9, 12, 1, 0, 10, 6")

    def test_selected_multiline_deletion(self) -> None:
        """Test selected multiline deletion."""
        case = (
            lspt.Position(line=4, character=44),
            lspt.Position(line=5, character=4),
            "",
            5,
            "selected Multi line Deletion",
        )
        self.document_lines[3] = (
            "can calculate_area(radius: float) -> float {return math.pi * radius * radius;"
        )
        del self.document_lines[4]
        self.check_semantic_token_update(case, "4, 0, 2, 3, 4, 14, 12, 1, 0, 15")

    def test_multi_line_insert_on_selected_region(self) -> None:
        """Test multi line insert on selected region."""
        case = (
            lspt.Position(line=4, character=26),
            lspt.Position(line=4, character=27),
            ':= a + a // 2) > 5 {\n        print("b is grater than 5");\n    }',
            1,
            "multi line insert on selected region ",
        )
        self.document_lines = [
            "",
            "import math;",
            "",
            '"""Function to calculate the area of a circle."""',
            "can calculate_area(radius::= a + a // 2) > 5 {",
            '        print("b is grater than 5");',
            "    }float) -> float {",
            "    return math.pi * radius * radius;",
            "}",
            " ",
        ]
        self.check_semantic_token_update(case, " 2, 1, 2, 14, 5, 2, 1, 1, ")
