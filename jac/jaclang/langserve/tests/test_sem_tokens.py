"""Test Semantic Tokens Update."""

import copy

import lsprotocol.types as lspt
import pytest

from jaclang.langserve.sem_manager import SemTokManager


@pytest.fixture
def initial_sem_tokens():
    """Fixture for initial semantic tokens."""
    # fmt: off
    return [
        1, 10, 4, 0, 2, 3, 4, 14, 12, 1, 0, 15, 6, 7, 1, 0, 8, 5, 2, 1,
        0, 10, 5, 2, 1, 1, 11, 4, 0, 2, 0, 10, 6, 7, 1, 0, 9, 6, 7, 1
    ]
    # fmt: on


@pytest.fixture
def document_lines():
    """Fixture for document lines."""
    return [
        "",
        "import math;",
        "",
        '"""Function to calculate the area of a circle."""',
        "can calculate_area(radius: float) -> float {",
        "    return math.pi * radius * radius;",
        "}",
        " ",
    ]


def check_semantic_token_update(
    case: tuple, expected_output: str, initial_sem_tokens: list, document_lines: list
) -> None:
    """Check semantic token update."""
    doc_lines = copy.deepcopy(document_lines)

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
        sem_tokens=copy.deepcopy(initial_sem_tokens),
        document_lines=doc_lines,
    )
    assert expected_output in str(updated_semtokens), f"\nFailed for case: {case[4]}"


def test_multiline_before_first_token(initial_sem_tokens, document_lines) -> None:
    """Test multiline before first token."""
    case = (
        lspt.Position(line=0, character=0),
        lspt.Position(line=0, character=0),
        "\n",
        0,
        "Multiline before first token (Basic)",
    )
    document_lines.insert(1, "")
    check_semantic_token_update(
        case, "2, 10, 4, 0, 2, 3, 4, 14,", initial_sem_tokens, document_lines
    )


def test_multiline_between_tokens(initial_sem_tokens, document_lines) -> None:
    """Test multiline between tokens."""
    case = (
        lspt.Position(line=5, character=19),
        lspt.Position(line=5, character=19),
        "\n    ",
        0,
        "Multiline between tokens (Basic)",
    )
    document_lines[5] = "    return math.pi "
    document_lines.insert(6, "    * radius * radius;")
    check_semantic_token_update(
        case, "2, 1, 6, 6, 7, 1, ", initial_sem_tokens, document_lines
    )


def test_multiline_at_end_of_line(initial_sem_tokens, document_lines) -> None:
    """Test multiline at end of line."""
    case = (
        lspt.Position(line=4, character=37),
        lspt.Position(line=4, character=37),
        "\n",
        0,
        "Multiline at end of line",
    )
    document_lines[4] = "can calculate_area(radius: float) -> "
    document_lines.insert(5, "float {")
    check_semantic_token_update(
        case, " 2, 1, 1, 0, 5, 2, 1, ", initial_sem_tokens, document_lines
    )


def test_sameline_space_between_tokens(initial_sem_tokens, document_lines) -> None:
    """Test sameline space between tokens."""
    case = (
        lspt.Position(line=5, character=20),
        lspt.Position(line=5, character=20),
        " ",
        0,
        "Sameline space between tokens (Basic)",
    )
    check_semantic_token_update(
        case, "0, 11, 6, 7, 1,", initial_sem_tokens, document_lines
    )


def test_sameline_tab_between_tokens(initial_sem_tokens, document_lines) -> None:
    """Test sameline tab between tokens."""
    case = (
        lspt.Position(line=5, character=20),
        lspt.Position(line=5, character=20),
        "    ",
        0,
        "Sameline tab between tokens (Basic)",
    )
    check_semantic_token_update(
        case, "0, 14, 6, 7, 1", initial_sem_tokens, document_lines
    )


def test_tab_at_start_of_token(initial_sem_tokens, document_lines) -> None:
    """Test tab at start of token."""
    case = (
        lspt.Position(line=5, character=21),
        lspt.Position(line=5, character=21),
        "   ",
        0,
        "Tab at start of a token",
    )
    check_semantic_token_update(
        case, "0, 13, 6, 7, 1,", initial_sem_tokens, document_lines
    )


def test_insert_inside_token(initial_sem_tokens, document_lines) -> None:
    """Test insert inside token."""
    case = (
        lspt.Position(line=5, character=13),
        lspt.Position(line=5, character=13),
        "calculate",
        0,
        "insert inside a token",
    )
    check_semantic_token_update(
        case, "1, 11, 13, 0, 2, 0, 19, 6, 7, 1", initial_sem_tokens, document_lines
    )


def test_insert_inside_token_selected_range(initial_sem_tokens, document_lines) -> None:
    """Test insert inside token selected range."""
    case = (
        lspt.Position(line=5, character=12),
        lspt.Position(line=5, character=14),
        "calculate",
        2,
        "insert inside a token in a selected range",
    )
    check_semantic_token_update(
        case, "1, 11, 11, 0, 2, 0, 17, 6, 7, 1,", initial_sem_tokens, document_lines
    )


def test_newline_at_start_of_token(initial_sem_tokens, document_lines) -> None:
    """Test newline at start of token."""
    case = (
        lspt.Position(line=5, character=21),
        lspt.Position(line=5, character=21),
        "\n    ",
        0,
        "Newline at start of a token",
    )
    document_lines[5] = "    return math.pi * "
    document_lines.insert(6, "    radius * radius;")
    check_semantic_token_update(
        case, "0, 2, 1, 4, 6, 7, 1, 0", initial_sem_tokens, document_lines
    )


def test_newline_after_parenthesis(initial_sem_tokens, document_lines) -> None:
    """Test newline after parenthesis."""
    case = (
        lspt.Position(line=4, character=19),
        lspt.Position(line=4, character=19),
        "\n    ",
        0,
        "Newline after parenthesis",
    )
    document_lines[4] = "can calculate_area("
    document_lines.insert(5, "    radius: float) -> float {")
    check_semantic_token_update(
        case, "12, 1, 1, 4, 6, 7, 1, 0, 8", initial_sem_tokens, document_lines
    )


def test_insert_newline_at_end_of_token(initial_sem_tokens, document_lines) -> None:
    """Test insert newline at end of token."""
    case = (
        lspt.Position(line=5, character=27),
        lspt.Position(line=5, character=27),
        "\n    ",
        0,
        "Insert Newline at end of a token",
    )
    document_lines[5] = "    return math.pi * radius"
    document_lines.insert(6, "     * radius;")
    check_semantic_token_update(
        case, "7, 1, 1, 7, 6, 7", initial_sem_tokens, document_lines
    )


def test_deletion_basic(initial_sem_tokens, document_lines) -> None:
    """Test deletion basic."""
    case = (
        lspt.Position(line=5, character=4),
        lspt.Position(line=5, character=4),
        "",
        4,
        "Deletion Basic",
    )
    check_semantic_token_update(
        case, "0, 10, 5, 2, 1, 1, 7, 4, 0, 2, 0", initial_sem_tokens, document_lines
    )


def test_multiline_deletion(initial_sem_tokens, document_lines) -> None:
    """Test multiline deletion."""
    case = (
        lspt.Position(line=3, character=49),
        lspt.Position(line=4, character=0),
        "",
        4,
        "Multiline Deletion",
    )
    document_lines[3] = (
        '"""Function to calculate the area of a circle."""can calculate_area(radius: float) -> float {'
    )
    del document_lines[4]
    check_semantic_token_update(
        case, "2, 2, 53, 14, 12, 1, 0", initial_sem_tokens, document_lines
    )


def test_single_deletion_inside_token(initial_sem_tokens, document_lines) -> None:
    """Test single deletion inside token."""
    case = (
        lspt.Position(line=5, character=12),
        lspt.Position(line=5, character=13),
        "",
        1,
        "single Deletion inside token",
    )
    check_semantic_token_update(
        case, "1, 1, 11, 3, 0, 2, 0, 9, 6", initial_sem_tokens, document_lines
    )


def test_deletion_inside_token_selected_range(
    initial_sem_tokens, document_lines
) -> None:
    """Test deletion inside token selected range."""
    case = (
        lspt.Position(line=4, character=10),
        lspt.Position(line=4, character=15),
        "",
        5,
        "Deletion inside token- selected range",
    )
    check_semantic_token_update(
        case, "4, 9, 12, 1, 0, 10, 6", initial_sem_tokens, document_lines
    )


def test_selected_multiline_deletion(initial_sem_tokens, document_lines) -> None:
    """Test selected multiline deletion."""
    case = (
        lspt.Position(line=4, character=44),
        lspt.Position(line=5, character=4),
        "",
        5,
        "selected Multi line Deletion",
    )
    document_lines[3] = (
        "can calculate_area(radius: float) -> float {return math.pi * radius * radius;"
    )
    del document_lines[4]
    check_semantic_token_update(
        case, "4, 0, 2, 3, 4, 14, 12, 1, 0, 15", initial_sem_tokens, document_lines
    )


def test_multi_line_insert_on_selected_region(
    initial_sem_tokens, document_lines
) -> None:
    """Test multi line insert on selected region."""
    case = (
        lspt.Position(line=4, character=26),
        lspt.Position(line=4, character=27),
        ':= a + a // 2) > 5 {\n        print("b is grater than 5");\n    }',
        1,
        "multi line insert on selected region ",
    )
    document_lines[:] = [
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
    check_semantic_token_update(
        case, " 2, 1, 2, 14, 5, 2, 1, 1, ", initial_sem_tokens, document_lines
    )
