"""Unit tests for the package.json edits of `add` and `remove` (pm/add.jac,
pm/remove.jac), against what bun 1.3.13 produced for the harness fixtures
(tools/pm_diff/golden/remove_basic, golden/aliases).

Run from the repo root:  jac run --backend native engine/tests/unit/test_pm_remove.jac
"""

import from engine.src.ffi.libc { fflush, _exit }
import from engine.src.pm.json {
    JVal,
    json_parse_str,
    JsonDoc,
    jv_get,
    jv_is_obj,
    jv_str_list
}
import from engine.src.pm.add {
    pm_package_json_add,
    pm_print_package_json,
    pm_jv_sort_keys,
    pm_jv_delete,
    pm_package_json_add_trusted
}
import from engine.src.pm.remove { pm_package_json_remove }

glob _ok: int = 0,
     _fail: int = 0;

def check(cond: bool, name: str) {
    if cond {
        _ok = _ok + 1;
    } else {
        _fail = _fail + 1;
        print("FAIL: " + name);
    }
}

def check_eq(got: str, want: str, name: str) {
    if got == want {
        _ok = _ok + 1;
    } else {
        _fail = _fail + 1;
        print("FAIL: " + name + " — got '" + got + "' want '" + want + "'");
    }
}

def parse(text: str) -> JVal {
    d: JsonDoc = json_parse_str(text);
    return d.value;
}

def keys_of(v: JVal) -> str {
    return ",".join(v.keys);
}

glob base: str = "{\n  \"name\": \"remove-basic\",\n  \"version\": \"1.0.0\",\n  \"private\": true,\n  \"dependencies\": {\n    \"is-even\": \"1.0.0\",\n    \"is-number\": \"7.0.0\"\n  },\n  \"devDependencies\": {\n    \"is-odd\": \"3.0.1\"\n  }\n}\n";

with entry {
    # remove a prod dependency: the group stays, alphabetized
    pj: JVal = parse(base);
    check_eq(
        str(pm_package_json_remove(pj, ["is-even"])), "1", "remove-dep: one match"
    );
    check_eq(
        keys_of(pj),
        "name,version,private,dependencies,devDependencies",
        "remove-dep: top-level order untouched"
    );
    check_eq(
        keys_of(jv_get(pj, "dependencies")),
        "is-number",
        "remove-dep: group keeps the rest"
    );
    check_eq(
        pm_print_package_json(pj, "  "),
        "{\n  \"name\": \"remove-basic\",\n  \"version\": \"1.0.0\",\n  \"private\": true,\n  \"dependencies\": {\n    \"is-number\": \"7.0.0\"\n  },\n  \"devDependencies\": {\n    \"is-odd\": \"3.0.1\"\n  }\n}\n",
        "remove-dep: printed like bun"
    );

    # remove the only dev dependency: the group goes and the top level is re-sorted canonically
    pj2: JVal = parse(base);
    check_eq(
        str(pm_package_json_remove(pj2, ["is-odd"])), "1", "remove-dev: one match"
    );
    check_eq(
        keys_of(pj2),
        "name,version,dependencies,private",
        "remove-dev: canonical order (private after the known keys)"
    );
    check(
        not jv_is_obj(jv_get(pj2, "devDependencies")), "remove-dev: empty group deleted"
    );

    # two names, one of which empties a group
    pj3: JVal = parse(base);
    check_eq(
        str(pm_package_json_remove(pj3, ["is-even", "is-odd"])),
        "2",
        "remove-two: both match"
    );
    check_eq(
        keys_of(pj3), "name,version,dependencies,private", "remove-two: canonical order"
    );
    check_eq(
        keys_of(jv_get(pj3, "dependencies")),
        "is-number",
        "remove-two: remaining dependency"
    );

    # a name that is not there changes nothing
    pj4: JVal = parse(base);
    check_eq(
        str(pm_package_json_remove(pj4, ["nope"])), "0", "remove-missing: no match"
    );
    check_eq(pm_print_package_json(pj4, "  "), base, "remove-missing: text unchanged");

    # the same name in several groups is removed from all of them
    pj5: JVal = parse(
        "{\"dependencies\": {\"x\": \"1\", \"a\": \"1\"}, \"peerDependencies\": {\"x\": \"1\"}, \"name\": \"p\"}"
    );
    check_eq(
        str(pm_package_json_remove(pj5, ["x"])), "1", "remove-multi: counted once"
    );
    check_eq(
        keys_of(pj5),
        "name,dependencies",
        "remove-multi: peer group gone, canonical order"
    );
    check_eq(
        keys_of(jv_get(pj5, "dependencies")), "a", "remove-multi: other entry kept"
    );

    # canonical sort: known keys in bun's order, unknown ones alphabetical after them
    pj6: JVal = parse(
        "{\"scripts\": {}, \"exports\": {}, \"private\": true, \"devDependencies\": {}, \"version\": \"1\", \"name\": \"n\", \"main\": \"i.js\", \"author\": \"a\"}"
    );
    pm_jv_sort_keys(pj6, True);
    check_eq(
        keys_of(pj6),
        "name,version,author,main,devDependencies,exports,private,scripts",
        "canonical sort"
    );

    # add re-alphabetizes the whole group (aliases fixture: is-number moved before odd-old)
    pj7: JVal = parse(
        "{\"dependencies\": {\"even\": \"npm:is-even@^1.0.0\", \"odd-three\": \"npm:is-odd@3.0.1\", \"is-number\": \"7.0.0\"}}"
    );
    pm_package_json_add(pj7, "dependencies", "odd-old", "npm:is-odd@0.1.2");
    check_eq(
        keys_of(jv_get(pj7, "dependencies")),
        "even,is-number,odd-old,odd-three",
        "add: group alphabetized"
    );
    pm_package_json_add(pj7, "devDependencies", "even", "^1.0.0");
    check(
        not (("even") in jv_get(pj7, "dependencies").vals),
        "add: moved out of the other group"
    );
    check_eq(keys_of(pj7), "dependencies,devDependencies", "add: new group appended");

    # jv_delete
    pj8: JVal = parse("{\"a\": 1, \"b\": 2}");
    check(
        pm_jv_delete(pj8, "a") and not pm_jv_delete(pj8, "zz"),
        "jv_delete return values"
    );
    check_eq(keys_of(pj8), "b", "jv_delete removes the key");

    # add --trust: names appended to trustedDependencies, new slots filled from the end (bun), existing kept
    pj9: JVal = parse("{\"name\": \"t\", \"dependencies\": {\"a\": \"1\"}}");
    check(
        pm_package_json_add_trusted(pj9, ["core-js"]), "trusted: added to a new array"
    );
    check_eq(
        keys_of(pj9),
        "name,dependencies,trustedDependencies",
        "trusted: array appended at the end"
    );
    check_eq(
        pm_print_package_json(pj9, "  "),
        "{\n  \"name\": \"t\",\n  \"dependencies\": {\n    \"a\": \"1\"\n  },\n  \"trustedDependencies\": [\n    \"core-js\"\n  ]\n}\n",
        "trusted: printed like bun"
    );
    check(
        not pm_package_json_add_trusted(pj9, ["core-js"]),
        "trusted: existing name not added twice"
    );
    check(pm_package_json_add_trusted(pj9, ["x", "y"]), "trusted: two new names");
    check_eq(
        ",".join(jv_str_list(jv_get(pj9, "trustedDependencies"))),
        "core-js,y,x",
        "trusted: new names in reverse order (bun fills from the end)"
    );

    print("pm_remove: passed=" + str(_ok) + " failed=" + str(_fail));
    fflush(0);
    if _fail > 0 {
        _exit(1);
    }
}
