"""Tests for backend/utils.jac — pure functions, no network required."""

import from backend.utils {
    empty_code_response,
    empty_error_message_response,
    empty_name_response,
    empty_query_response,
    extract_first_error
}

# empty_code_response
test "empty_code_response sets ok to false" {
    r = empty_code_response("validate_jac");
    assert not r["ok"];
}

test "empty_code_response carries the given tool name" {
    r = empty_code_response("format_jac");
    assert r["tool"] == "format_jac" , f"Expected 'format_jac', got '{r['tool']}'";
}

test "empty_code_response has the expected error message" {
    r = empty_code_response("check_syntax");
    assert r["error"]["message"] == "Code cannot be empty." , f"Got: '{r['error'][
        'message'
    ]}'";
}

test "empty_code_response data is an empty dict" {
    r = empty_code_response("validate_jac");
    assert r["data"] == {} , f"Expected empty dict, got {r['data']}";
}

# empty_error_message_response
test "empty_error_message_response sets ok to false" {
    r = empty_error_message_response();
    assert not r["ok"];
}

test "empty_error_message_response tool is explain_error" {
    r = empty_error_message_response();
    assert r["tool"] == "explain_error" , f"Got: '{r['tool']}'";
}

test "empty_error_message_response has a non-empty error message" {
    r = empty_error_message_response();
    assert r["error"]["message"] != "" , "Error message should not be empty";
}

# empty_name_response
test "empty_name_response sets ok to false" {
    r = empty_name_response();
    assert not r["ok"];
}

test "empty_name_response tool is get_example" {
    r = empty_name_response();
    assert r["tool"] == "get_example" , f"Got: '{r['tool']}'";
}

# empty_query_response
test "empty_query_response sets ok to false" {
    r = empty_query_response();
    assert not r["ok"];
}

test "empty_query_response tool is search_docs" {
    r = empty_query_response();
    assert r["tool"] == "search_docs" , f"Got: '{r['tool']}'";
}

# extract_first_error
test "extract_first_error returns the first error message" {
    result = {
        "data": {
            "errors": [{"message": "unexpected token"}, {"message": "second error"}]
        }
    };
    assert extract_first_error(result) == "unexpected token" , f"Got: '{extract_first_error(
        result
    )}'";
}

test "extract_first_error returns empty string when errors list is missing" {
    result = {"data": {}};
    assert extract_first_error(result) == "" , f"Got: '{extract_first_error(result)}'";
}

test "extract_first_error returns empty string when data key is missing" {
    result = {};
    assert extract_first_error(result) == "" , f"Got: '{extract_first_error(result)}'";
}

test "extract_first_error returns empty string when errors list is empty" {
    result = {"data": {"errors": []}};
    assert extract_first_error(result) == "" , f"Got: '{extract_first_error(result)}'";
}

test "extract_first_error returns empty string for non-dict error entry" {
    result = {"data": {"errors": ["plain string error"]}};
    assert extract_first_error(result) == "" , f"Got: '{extract_first_error(result)}'";
}
