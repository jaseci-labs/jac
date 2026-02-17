"""Test Semantic Tokens Update."""

import copy;
import lsprotocol.types as lspt;
import from jaclang.langserve.sem_manager { SemTokManager }

def get_initial_sem_tokens -> list[int] {
    return [
        1,
        10,
        4,
        0,
        2,
        3,
        4,
        14,
        12,
        1,
        0,
        15,
        6,
        7,
        1,
        0,
        8,
        5,
        2,
        1,
        0,
        10,
        5,
        2,
        1,
        1,
        11,
        4,
        0,
        2,
        0,
        10,
        6,
        7,
        1,
        0,
        9,
        6,
        7,
        1
    ];
}

def get_document_lines -> list[str] {
    return [
        "",
        "import math;",
        "",
        '"""Function to calculate the area of a circle."""',
        "can calculate_area(radius: float) -> float {",
        "    return math.pi * radius * radius;",
        "}",
        " "
    ];
}

def check_semantic_token_update(
    test_case: tuple,
    expected_output: str,
    initial_sem_tokens: list[int],
    document_lines: list[str]
) {
    doc_lines = copy.deepcopy(document_lines);
    updated_semtokens = SemTokManager.update_sem_tokens(
        "circle_ir",
        lspt.DidChangeTextDocumentParams(
            text_document=lspt.VersionedTextDocumentIdentifier(
                version=32, uri="...jaclang/examples/manual_code/circle.jac"
            ),
            content_changes=[
                lspt.TextDocumentContentChangeEvent_Type1(
                    range=lspt.Range(start=test_case[0], end=test_case[1]),
                    text=test_case[2],
                    range_length=test_case[3]
                )
            ]
        ),
        sem_tokens=copy.deepcopy(initial_sem_tokens),
        document_lines=doc_lines
    );
    assert expected_output in str(updated_semtokens) , f"\nFailed for case: {test_case[
        4
    ]}";
}

test "multiline before first token" {
    tokens = get_initial_sem_tokens();
    lines = get_document_lines();
    test_case = (
        lspt.Position(line=0, character=0),
        lspt.Position(line=0, character=0),
        "\n",
        0,
        "Multiline before first token (Basic)"
    );
    lines.insert(1, "");
    check_semantic_token_update(test_case, "2, 10, 4, 0, 2, 3, 4, 14,", tokens, lines);
}

test "multiline between tokens" {
    tokens = get_initial_sem_tokens();
    lines = get_document_lines();
    test_case = (
        lspt.Position(line=5, character=19),
        lspt.Position(line=5, character=19),
        "\n    ",
        0,
        "Multiline between tokens (Basic)"
    );
    lines[5] = "    return math.pi ";
    lines.insert(6, "    * radius * radius;");
    check_semantic_token_update(test_case, "2, 1, 6, 6, 7, 1, ", tokens, lines);
}

test "multiline at end of line" {
    tokens = get_initial_sem_tokens();
    lines = get_document_lines();
    test_case = (
        lspt.Position(line=4, character=37),
        lspt.Position(line=4, character=37),
        "\n",
        0,
        "Multiline at end of line"
    );
    lines[4] = "can calculate_area(radius: float) -> ";
    lines.insert(5, "float {");
    check_semantic_token_update(test_case, " 2, 1, 1, 0, 5, 2, 1, ", tokens, lines);
}

test "sameline space between tokens" {
    tokens = get_initial_sem_tokens();
    lines = get_document_lines();
    test_case = (
        lspt.Position(line=5, character=20),
        lspt.Position(line=5, character=20),
        " ",
        0,
        "Sameline space between tokens (Basic)"
    );
    check_semantic_token_update(test_case, "0, 11, 6, 7, 1,", tokens, lines);
}

test "sameline tab between tokens" {
    tokens = get_initial_sem_tokens();
    lines = get_document_lines();
    test_case = (
        lspt.Position(line=5, character=20),
        lspt.Position(line=5, character=20),
        "    ",
        0,
        "Sameline tab between tokens (Basic)"
    );
    check_semantic_token_update(test_case, "0, 14, 6, 7, 1", tokens, lines);
}

test "tab at start of token" {
    tokens = get_initial_sem_tokens();
    lines = get_document_lines();
    test_case = (
        lspt.Position(line=5, character=21),
        lspt.Position(line=5, character=21),
        "   ",
        0,
        "Tab at start of a token"
    );
    check_semantic_token_update(test_case, "0, 13, 6, 7, 1,", tokens, lines);
}

test "insert inside token" {
    tokens = get_initial_sem_tokens();
    lines = get_document_lines();
    test_case = (
        lspt.Position(line=5, character=13),
        lspt.Position(line=5, character=13),
        "calculate",
        0,
        "insert inside a token"
    );
    check_semantic_token_update(
        test_case, "1, 11, 13, 0, 2, 0, 19, 6, 7, 1", tokens, lines
    );
}

test "insert inside token selected range" {
    tokens = get_initial_sem_tokens();
    lines = get_document_lines();
    test_case = (
        lspt.Position(line=5, character=12),
        lspt.Position(line=5, character=14),
        "calculate",
        2,
        "insert inside a token in a selected range"
    );
    check_semantic_token_update(
        test_case, "1, 11, 11, 0, 2, 0, 17, 6, 7, 1,", tokens, lines
    );
}

test "newline at start of token" {
    tokens = get_initial_sem_tokens();
    lines = get_document_lines();
    test_case = (
        lspt.Position(line=5, character=21),
        lspt.Position(line=5, character=21),
        "\n    ",
        0,
        "Newline at start of a token"
    );
    lines[5] = "    return math.pi * ";
    lines.insert(6, "    radius * radius;");
    check_semantic_token_update(test_case, "0, 2, 1, 4, 6, 7, 1, 0", tokens, lines);
}

test "newline after parenthesis" {
    tokens = get_initial_sem_tokens();
    lines = get_document_lines();
    test_case = (
        lspt.Position(line=4, character=19),
        lspt.Position(line=4, character=19),
        "\n    ",
        0,
        "Newline after parenthesis"
    );
    lines[4] = "can calculate_area(";
    lines.insert(5, "    radius: float) -> float {");
    check_semantic_token_update(test_case, "12, 1, 1, 4, 6, 7, 1, 0, 8", tokens, lines);
}

test "insert newline at end of token" {
    tokens = get_initial_sem_tokens();
    lines = get_document_lines();
    test_case = (
        lspt.Position(line=5, character=27),
        lspt.Position(line=5, character=27),
        "\n    ",
        0,
        "Insert Newline at end of a token"
    );
    lines[5] = "    return math.pi * radius";
    lines.insert(6, "     * radius;");
    check_semantic_token_update(test_case, "7, 1, 1, 7, 6, 7", tokens, lines);
}

test "deletion basic" {
    tokens = get_initial_sem_tokens();
    lines = get_document_lines();
    test_case = (
        lspt.Position(line=5, character=4),
        lspt.Position(line=5, character=4),
        "",
        4,
        "Deletion Basic"
    );
    check_semantic_token_update(
        test_case, "0, 10, 5, 2, 1, 1, 7, 4, 0, 2, 0", tokens, lines
    );
}

test "multiline deletion" {
    tokens = get_initial_sem_tokens();
    lines = get_document_lines();
    test_case = (
        lspt.Position(line=3, character=49),
        lspt.Position(line=4, character=0),
        "",
        4,
        "Multiline Deletion"
    );
    lines[3] = '"""Function to calculate the area of a circle."""can calculate_area(radius: float) -> float {';
    del lines[4];
    check_semantic_token_update(test_case, "2, 2, 53, 14, 12, 1, 0", tokens, lines);
}

test "single deletion inside token" {
    tokens = get_initial_sem_tokens();
    lines = get_document_lines();
    test_case = (
        lspt.Position(line=5, character=12),
        lspt.Position(line=5, character=13),
        "",
        1,
        "single Deletion inside token"
    );
    check_semantic_token_update(test_case, "1, 1, 11, 3, 0, 2, 0, 9, 6", tokens, lines);
}

test "deletion inside token selected range" {
    tokens = get_initial_sem_tokens();
    lines = get_document_lines();
    test_case = (
        lspt.Position(line=4, character=10),
        lspt.Position(line=4, character=15),
        "",
        5,
        "Deletion inside token- selected range"
    );
    check_semantic_token_update(test_case, "4, 9, 12, 1, 0, 10, 6", tokens, lines);
}

test "selected multiline deletion" {
    tokens = get_initial_sem_tokens();
    lines = get_document_lines();
    test_case = (
        lspt.Position(line=4, character=44),
        lspt.Position(line=5, character=4),
        "",
        5,
        "selected Multi line Deletion"
    );
    lines[3] = "can calculate_area(radius: float) -> float {return math.pi * radius * radius;";
    del lines[4];
    check_semantic_token_update(
        test_case, "4, 0, 2, 3, 4, 14, 12, 1, 0, 15", tokens, lines
    );
}

test "multi line insert on selected region" {
    tokens = get_initial_sem_tokens();
    lines = get_document_lines();
    test_case = (
        lspt.Position(line=4, character=26),
        lspt.Position(line=4, character=27),
        ':= a + a // 2) > 5 {\n        print("b is grater than 5");\n    }',
        1,
        "multi line insert on selected region "
    );
    lines[:] = [
        "",
        "import math;",
        "",
        '"""Function to calculate the area of a circle."""',
        "can calculate_area(radius::= a + a // 2) > 5 {",
        '        print("b is grater than 5");',
        "    }float) -> float {",
        "    return math.pi * radius * radius;",
        "}",
        " "
    ];
    check_semantic_token_update(test_case, " 2, 1, 2, 14, 5, 2, 1, 1, ", tokens, lines);
}
