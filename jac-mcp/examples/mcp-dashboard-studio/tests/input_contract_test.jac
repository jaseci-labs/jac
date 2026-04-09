"""Parameterized fixture tests — systematic input coverage via shared fixture data.

Each `parametrize()` call registers one test case per fixture entry, so adding a new
blank-input variant (e.g. a unicode space) automatically expands every walker's coverage.
"""

import from jaclang.runtimelib.test { parametrize }

import from main {
    validate_jac,
    check_syntax,
    format_jac,
    py_to_jac,
    get_ast,
    explain_error,
    get_example,
    search_docs
}
import from backend.utils { extract_first_error }

# Fixture data
# Extending any of these lists automatically exercises every walker registered
# below with the new variant. No test code changes required.
glob BLANK_CODE: list = ["", " ", "\t", "\n", "   \n\t  ", "\r\n"],
     BLANK_MESSAGE: list = ["", " ", "\t", "\n", "  \t\n  "],
     BLANK_NAME: list = ["", " ", "\t", "  \n  "],
     BLANK_QUERY: list = ["", " ", "\n", "\t\t"];

# Walker test functions
def _check_validate_jac(code: str) {
    w = root spawn validate_jac(code=code);
    r = w.reports[0];
    assert not r["ok"] , f"validate_jac: expected ok=false for {repr(code)}";
    assert r["tool"] == "validate_jac" , f"Expected tool=validate_jac, got {r['tool']}";
    assert r["error"]["message"] != "" , "Expected a non-empty error message";
}

def _check_check_syntax(code: str) {
    w = root spawn check_syntax(code=code);
    r = w.reports[0];
    assert not r["ok"] , f"check_syntax: expected ok=false for {repr(code)}";
    assert r["tool"] == "check_syntax" , f"Expected tool=check_syntax, got {r['tool']}";
}

def _check_format_jac(code: str) {
    w = root spawn format_jac(code=code);
    r = w.reports[0];
    assert not r["ok"] , f"format_jac: expected ok=false for {repr(code)}";
    assert r["tool"] == "format_jac" , f"Expected tool=format_jac, got {r['tool']}";
}

def _check_py_to_jac(code: str) {
    w = root spawn py_to_jac(code=code);
    r = w.reports[0];
    assert not r["ok"] , f"py_to_jac: expected ok=false for {repr(code)}";
    assert r["tool"] == "py_to_jac" , f"Expected tool=py_to_jac, got {r['tool']}";
}

def _check_get_ast(code: str) {
    w = root spawn get_ast(code=code);
    r = w.reports[0];
    assert not r["ok"] , f"get_ast: expected ok=false for {repr(code)}";
    assert r["tool"] == "get_ast" , f"Expected tool=get_ast, got {r['tool']}";
}

def _check_explain_error(msg: str) {
    w = root spawn explain_error(error_message=msg);
    r = w.reports[0];
    assert not r["ok"] , f"explain_error: expected ok=false for {repr(msg)}";
    assert r["tool"] == "explain_error" , f"Expected tool=explain_error, got {r['tool']}";
}

def _check_get_example(name: str) {
    w = root spawn get_example(name=name);
    r = w.reports[0];
    assert not r["ok"] , f"get_example: expected ok=false for {repr(name)}";
    assert r["tool"] == "get_example" , f"Expected tool=get_example, got {r['tool']}";
}

def _check_search_docs(query: str) {
    w = root spawn search_docs(query=query);
    r = w.reports[0];
    assert not r["ok"] , f"search_docs: expected ok=false for {repr(query)}";
    assert r["tool"] == "search_docs" , f"Expected tool=search_docs, got {r['tool']}";
}

# Response envelope shape fixture
# Every walker response must carry these four keys — parametrize ensures each
# key is individually verified so a missing key produces a focused failure.
glob ENVELOPE_KEYS: list = ["ok", "tool", "data", "error"];

def _check_validate_jac_envelope(key: str) {
    w = root spawn validate_jac(code="");
    assert key in w.reports[0] , f"validate_jac response missing required key: '{key}'";
}

def _check_explain_error_envelope(key: str) {
    w = root spawn explain_error(error_message="");
    assert key in w.reports[0] , f"explain_error response missing required key: '{key}'";
}

def _check_search_docs_envelope(key: str) {
    w = root spawn search_docs(query="");
    assert key in w.reports[0] , f"search_docs response missing required key: '{key}'";
}

# extract_first_error fixture table
# (input_dict, expected_output) pairs — replaces the five manual tests in
# utils_test.jac with a single parametrized table that is easier to extend.
glob ERROR_FIXTURES: list = [
         ({"data": {"errors": [{"message": "unexpected token"}]}}, "unexpected token"),
         (
             {
                 "data": {
                     "errors": [
                         {"message": "type mismatch"},
                         {"message": "second error"}
                     ]
                 }
             },
             "type mismatch"
         ),
         ({"data": {"errors": []}}, ""),
         ({"data": {}}, ""),
         ({}, ""),
         ({"data": {"errors": ["plain string not a dict"]}}, ""),
         ({"data": {"errors": [{}]}}, ""),
         ({"data": {"errors": [{"message": ""}]}}, ""),

     ];

def _check_extract_first_error(pair: tuple) {
    got = extract_first_error(pair[0]);
    assert got == pair[1] , f"extract_first_error: expected '{pair[1]}', got '{got}'";
}

# Registration

# Code-walker blank input fixture: 6 variants × 5 walkers = 30 tests
with entry {
    parametrize("validate_jac_blank", BLANK_CODE, _check_validate_jac);
    parametrize("check_syntax_blank", BLANK_CODE, _check_check_syntax);
    parametrize("format_jac_blank", BLANK_CODE, _check_format_jac);
    parametrize("py_to_jac_blank", BLANK_CODE, _check_py_to_jac);
    parametrize("get_ast_blank", BLANK_CODE, _check_get_ast);

    # Non-code blank input fixtures
    parametrize("explain_error_blank", BLANK_MESSAGE, _check_explain_error);
    parametrize("get_example_blank", BLANK_NAME, _check_get_example);
    parametrize("search_docs_blank", BLANK_QUERY, _check_search_docs);

    # Response envelope shape: 4 keys × 3 walkers = 12 tests
    parametrize("validate_jac_envelope", ENVELOPE_KEYS, _check_validate_jac_envelope);
    parametrize("explain_error_envelope", ENVELOPE_KEYS, _check_explain_error_envelope);
    parametrize("search_docs_envelope", ENVELOPE_KEYS, _check_search_docs_envelope);

    # extract_first_error: 8 fixture rows
    parametrize("extract_first_error", ERROR_FIXTURES, _check_extract_first_error);
}
