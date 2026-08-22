"""Portability check pass tests."""

import os;
import from tests.support { JAC_ROOT }
import jaclang;
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures", "portability"
     );

def has_warning_code(prog: JacProgram, code: str) -> bool {
    for alert in prog.warnings_had {
        if alert.code is not None and alert.code.code == code {
            return True;
        }
    }
    return False;
}

def count_warning_code(prog: JacProgram, code: str) -> int {
    count = 0;
    for alert in prog.warnings_had {
        if alert.code is not None and alert.code.code == code {
            count += 1;
        }
    }
    return count;
}

def get_warnings_with_code(prog: JacProgram, code: str) -> list {
    return [
        w
        for w in prog.warnings_had
        if w.code is not None and w.code.code == code
    ];
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# W6001: JS-specific globals
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
test "console usage produces W6001 warning" {
    file_path = os.path.join(FIXTURES, "js_globals.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warnings = get_warnings_with_code(prog, "W6001");
    warning_msgs = [str(w) for w in warnings];
    assert any("console" in w for w in warning_msgs) , f"Expected W6001 warning for 'console', got: {warning_msgs}";
}

test "Math usage produces W6001 warning" {
    file_path = os.path.join(FIXTURES, "js_globals.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warnings = get_warnings_with_code(prog, "W6001");
    warning_msgs = [str(w) for w in warnings];
    assert any("Math" in w for w in warning_msgs) , f"Expected W6001 warning for 'Math', got: {warning_msgs}";
}

test "JSON usage produces W6001 warning" {
    file_path = os.path.join(FIXTURES, "js_globals.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warnings = get_warnings_with_code(prog, "W6001");
    warning_msgs = [str(w) for w in warnings];
    assert any("JSON" in w for w in warning_msgs) , f"Expected W6001 warning for 'JSON', got: {warning_msgs}";
}

test "Array/Object/Map/Set constructors produce W6001 warnings" {
    file_path = os.path.join(FIXTURES, "js_globals.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warnings = get_warnings_with_code(prog, "W6001");
    warning_msgs = [str(w) for w in warnings];
    assert any("Array" in w for w in warning_msgs) , f"Expected W6001 warning for 'Array', got: {warning_msgs}";
    assert any("Object" in w for w in warning_msgs) , f"Expected W6001 warning for 'Object', got: {warning_msgs}";
    assert any("Map" in w for w in warning_msgs) , f"Expected W6001 warning for 'Map', got: {warning_msgs}";
}

test "setTimeout/setInterval produce W6001 warnings" {
    file_path = os.path.join(FIXTURES, "js_globals.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warnings = get_warnings_with_code(prog, "W6001");
    warning_msgs = [str(w) for w in warnings];
    assert any("setTimeout" in w for w in warning_msgs) , f"Expected W6001 warning for 'setTimeout', got: {warning_msgs}";
    assert any("setInterval" in w for w in warning_msgs) , f"Expected W6001 warning for 'setInterval', got: {warning_msgs}";
}

test "multiple JS globals produce correct count of W6001 warnings" {
    file_path = os.path.join(FIXTURES, "js_globals.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    count = count_warning_code(prog, "W6001");
    # console (2: log, warn), Math (2: floor, ceil), JSON (2: parse, stringify),
    # Array, Object, Map, Set (4), setTimeout, setInterval (2) = 12
    assert count >= 10 , f"Expected at least 10 W6001 warnings for JS globals, got: {count}";
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# W6002: JS-idiomatic methods
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
test "push method produces W6002 warning" {
    file_path = os.path.join(FIXTURES, "js_methods.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warnings = get_warnings_with_code(prog, "W6002");
    warning_msgs = [str(w) for w in warnings];
    assert any("push" in w for w in warning_msgs) , f"Expected W6002 warning for '.push()', got: {warning_msgs}";
}

test "forEach method produces W6002 warning" {
    file_path = os.path.join(FIXTURES, "js_methods.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warnings = get_warnings_with_code(prog, "W6002");
    warning_msgs = [str(w) for w in warnings];
    assert any("forEach" in w for w in warning_msgs) , f"Expected W6002 warning for '.forEach()', got: {warning_msgs}";
}

test "indexOf method produces W6002 warning" {
    file_path = os.path.join(FIXTURES, "js_methods.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warnings = get_warnings_with_code(prog, "W6002");
    warning_msgs = [str(w) for w in warnings];
    assert any("indexOf" in w for w in warning_msgs) , f"Expected W6002 warning for '.indexOf()', got: {warning_msgs}";
}

test "string JS methods produce W6002 warnings" {
    file_path = os.path.join(FIXTURES, "js_methods.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warnings = get_warnings_with_code(prog, "W6002");
    warning_msgs = [str(w) for w in warnings];
    assert any("charAt" in w for w in warning_msgs) , f"Expected W6002 warning for '.charAt()', got: {warning_msgs}";
    assert any("charCodeAt" in w for w in warning_msgs) , f"Expected W6002 warning for '.charCodeAt()', got: {warning_msgs}";
    assert any("substring" in w for w in warning_msgs) , f"Expected W6002 warning for '.substring()', got: {warning_msgs}";
}

test "functional methods (every, some, find) produce W6002 warnings" {
    file_path = os.path.join(FIXTURES, "js_methods.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warnings = get_warnings_with_code(prog, "W6002");
    warning_msgs = [str(w) for w in warnings];
    assert any("every" in w for w in warning_msgs) , f"Expected W6002 warning for '.every()', got: {warning_msgs}";
    assert any("some" in w for w in warning_msgs) , f"Expected W6002 warning for '.some()', got: {warning_msgs}";
    assert any("find" in w and "findIndex" not in w for w in warning_msgs) , f"Expected W6002 warning for '.find()', got: {warning_msgs}";
}

test "str.find with string arguments produces no W6002 warning" {
    file_path = os.path.join(FIXTURES, "py_str_find.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warnings = get_warnings_with_code(prog, "W6002");
    warning_msgs = [str(w) for w in warnings];
    assert not any("find" in w for w in warning_msgs) , f"str.find is Python-congruent and must not warn, got: {warning_msgs}";
}

test "find with a lambda callback produces W6002 warning" {
    file_path = os.path.join(FIXTURES, "js_methods.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    count = count_warning_code(prog, "W6002");
    warnings = get_warnings_with_code(prog, "W6002");
    warning_msgs = [str(w) for w in warnings];
    find_hits = len(
        [
            w
            for w in warning_msgs
            if ".find(" in w
        ]
    );
    assert find_hits >= 2 , f"Expected find warnings for both function-ref and lambda callbacks, got: {warning_msgs}";
    assert count >= 16 , f"Expected the lambda find call to add a W6002, got count: {count}";
}

test "conversion methods (toFixed, toString) produce W6002 warnings" {
    file_path = os.path.join(FIXTURES, "js_methods.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warnings = get_warnings_with_code(prog, "W6002");
    warning_msgs = [str(w) for w in warnings];
    assert any("toFixed" in w for w in warning_msgs) , f"Expected W6002 warning for '.toFixed()', got: {warning_msgs}";
    assert any("toString" in w for w in warning_msgs) , f"Expected W6002 warning for '.toString()', got: {warning_msgs}";
}

test "multiple JS methods produce correct count of W6002 warnings" {
    file_path = os.path.join(FIXTURES, "js_methods.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    count = count_warning_code(prog, "W6002");
    # push, forEach, indexOf, splice, unshift, shift, includes (7)
    # charAt, charCodeAt, substring, padStart, trim (5)
    # every, some, find, findIndex (4)
    # hasOwnProperty, entries, keys, values (4)
    # toFixed, toPrecision, toString (3)
    assert count >= 15 , f"Expected at least 15 W6002 warnings for JS methods, got: {count}";
}

test "user-defined methods sharing JS names do not warn W6002" {
    file_path = os.path.join(FIXTURES, "user_defined_members.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warnings = get_warnings_with_code(prog, "W6002");
    warning_msgs = [str(w) for w in warnings];
    assert not any("parse" in w for w in warning_msgs) , f"Config.parse is a declared method, must not warn: {warning_msgs}";
    assert not any("assign" in w for w in warning_msgs) , f"Config.assign is a declared method, must not warn: {warning_msgs}";
    # The fixture calls .push twice: once on Config (declared) and once on a
    # bare list (JS idiom). Only the list call may warn.
    push_hits = len(
        [
            w
            for w in warning_msgs
            if "push" in w
        ]
    );
    assert push_hits == 1 , f"Expected exactly the list .push() call to warn, got: {warning_msgs}";
}

test "user-declared length field access does not warn W6004" {
    file_path = os.path.join(FIXTURES, "user_defined_members.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warnings = get_warnings_with_code(prog, "W6004");
    warning_msgs = [str(w) for w in warnings];
    # cfg.length resolves to the declared field; items.length stays JS slop.
    length_hits = len(
        [
            w
            for w in warning_msgs
            if "length" in w
        ]
    );
    assert length_hits == 1 , f"Expected exactly the list .length access to warn, got: {warning_msgs}";
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# W6003: JS-specific keywords
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
test "undefined keyword produces W6003 warning" {
    file_path = os.path.join(FIXTURES, "js_keywords.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warnings = get_warnings_with_code(prog, "W6003");
    warning_msgs = [str(w) for w in warnings];
    assert any("undefined" in w for w in warning_msgs) , f"Expected W6003 warning for 'undefined', got: {warning_msgs}";
}

test "typeof keyword produces W6003 warning" {
    file_path = os.path.join(FIXTURES, "js_keywords.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warnings = get_warnings_with_code(prog, "W6003");
    warning_msgs = [str(w) for w in warnings];
    assert any("typeof" in w for w in warning_msgs) , f"Expected W6003 warning for 'typeof', got: {warning_msgs}";
}

test "void keyword produces W6003 warning" {
    file_path = os.path.join(FIXTURES, "js_keywords.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warnings = get_warnings_with_code(prog, "W6003");
    warning_msgs = [str(w) for w in warnings];
    assert any("void" in w for w in warning_msgs) , f"Expected W6003 warning for 'void', got: {warning_msgs}";
}

test "JS keywords produce correct count of W6003 warnings" {
    file_path = os.path.join(FIXTURES, "js_keywords.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    count = count_warning_code(prog, "W6003");
    # undefined, typeof, void = 3
    assert count >= 3 , f"Expected at least 3 W6003 warnings, got: {count}";
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# W6004: JS-specific properties
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
test "length property produces W6004 warning" {
    file_path = os.path.join(FIXTURES, "js_properties.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warnings = get_warnings_with_code(prog, "W6004");
    warning_msgs = [str(w) for w in warnings];
    assert any("length" in w for w in warning_msgs) , f"Expected W6004 warning for '.length', got: {warning_msgs}";
}

test "prototype property produces W6004 warning" {
    file_path = os.path.join(FIXTURES, "js_properties.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    warnings = get_warnings_with_code(prog, "W6004");
    warning_msgs = [str(w) for w in warnings];
    assert any("prototype" in w for w in warning_msgs) , f"Expected W6004 warning for '.prototype', got: {warning_msgs}";
}

test "JS properties produce correct count of W6004 warnings" {
    file_path = os.path.join(FIXTURES, "js_properties.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    count = count_warning_code(prog, "W6004");
    # items.length, s.length, MyObj.prototype = 3
    assert count >= 3 , f"Expected at least 3 W6004 warnings, got: {count}";
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Clean code: no portability warnings
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
test "clean Jac code produces no portability warnings" {
    file_path = os.path.join(FIXTURES, "clean_jac.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    portability_warnings = [
        w
        for w in prog.warnings_had
        if w.code is not None and w.code.code.startswith("W6")
    ];
    assert len(portability_warnings) == 0 , f"Expected no portability warnings for clean code, got: {[
        str(w) for w in portability_warnings
    ]}";
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Mixed usage
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
test "mixed code produces warnings only for JS idioms" {
    file_path = os.path.join(FIXTURES, "mixed_usage.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    # Should have W6001 for console
    assert has_warning_code(prog, "W6001") , "Expected W6001 for console.log in mixed code";
    # Should have W6002 for push, forEach
    assert has_warning_code(prog, "W6002") , "Expected W6002 for .push()/.forEach() in mixed code";
    # Should have W6004 for .length
    assert has_warning_code(prog, "W6004") , "Expected W6004 for .length in mixed code";
}

test "mixed code warning messages include alternatives" {
    file_path = os.path.join(FIXTURES, "mixed_usage.jac");
    prog = JacProgram();
    prog.compile(file_path, type_check=True);
    w6001_warnings = get_warnings_with_code(prog, "W6001");
    # Check that warning message suggests the alternative
    assert any("print()" in str(w) for w in w6001_warnings) , f"Expected W6001 to suggest 'print()' as alternative, got: {[
        str(w) for w in w6001_warnings
    ]}";
}
