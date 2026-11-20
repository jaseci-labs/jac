"""The walker wire contract (#8906).

A walker spawn answers with the executed walker in `result` (its `has` fields
as the walk left them, plus the type markers) and the values it reported in
`reports`. The report list is never repeated inside `result`, wherever the
walker sits in the payload.

Setup mirrors `test_serve_client.jac`: one `make_*_client` per fixture over
`JacTestClient.from_file`.
"""
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.testing.testing { JacTestClient }

glob FIXTURES = str(Path(__file__).parent / "fixtures");


def fixture_abs_path(filename: str) -> str {
    return str((Path(FIXTURES) / filename).resolve());
}


def make_walker_wire_client(base_path: str) -> JacTestClient {
    client = JacTestClient.from_file(
        fixture_abs_path("serve_walker_wire.jac"), base_path=base_path
    );
    client.register_user("wire", "secret123");
    return client;
}

"""Names of every walker in a payload that still carries an inline report list."""
def _walkers_keeping_report_copies(value: any) -> list[str] {
    found: list[str] = [];
    if isinstance(value, dict) {
        if value.get("_jac_archetype") == "walker" and "reports" in value {
            found.append(str(value.get("_jac_type")));
        }
        for v in value.values() {
            found = found + _walkers_keeping_report_copies(v);
        }
    } elif isinstance(value, list) {
        for v in value {
            found = found + _walkers_keeping_report_copies(v);
        }
    }
    return found;
}

"""Match `expected` as a subset, so wire bookkeeping like _jac_id is ignored."""
def _wire_matches(actual: any, expected: any) -> bool {
    if isinstance(expected, dict) {
        if not isinstance(actual, dict) {
            return False;
        }
        for (k, v) in expected.items() {
            if (k not in actual) or (not _wire_matches(actual[k], v)) {
                return False;
            }
        }
        return True;
    }
    if isinstance(expected, list) {
        if (not isinstance(actual, list)) or (len(actual) != len(expected)) {
            return False;
        }
        for (a, e) in zip(actual, expected) {
            if not _wire_matches(a, e) {
                return False;
            }
        }
        return True;
    }
    return actual == expected;
}

test "serve walker response keeps its fields and no copy of its reports" {
    # (path, body, expected `result` subset, expected envelope reports)
    cases = [
        (
            "/walker/Outer",
            {"tag": "t1"},
            {"_jac_archetype": "walker", "tag": "t1"},
            [{"inner": True}, {"outer": "t1"}]
        ),
        ("/walker/CountThings", {}, {"total": 1}, []),
        # `report self` used to recurse through the copy and answer 500.
        ("/walker/SelfReporter", {}, {"tag": "me"}, [{"tag": "me"}]),
        (
            "/function/spawn_and_return_walker",
            {"tag": "q"},
            {"tag": "q"},
            [{"inner": True}, {"outer": "q"}]
        )
    ];
    with TemporaryDirectory() as tmpdir {
        client = make_walker_wire_client(tmpdir);
        for (path, body, want_result, want_reports) in cases {
            response = client.post(path, json=body);
            assert response.ok , f"{path} answered {response.status_code}";
            data = response.data;
            repeats = _walkers_keeping_report_copies(data);
            assert repeats == [] , (
                f"{path}: walkers still carrying an inline report list: {repeats}"
            );
            got_result = data["result"];
            assert _wire_matches(got_result, want_result) , (
                f"{path}: result {got_result} does not match {want_result}"
            );
            got_reports = data["reports"];
            assert _wire_matches(got_reports, want_reports) , (
                f"{path}: reports {got_reports} do not match {want_reports}"
            );
        }
        client.close();
    }
}

test "serve function response carries its return value beside the reports made under it" {
    # (path, body, expected `result`, expected envelope reports)
    cases = [
        (
            "/function/list_things",
            {"n": 2},
            [{"name": "t0", "idx": 0}, {"name": "t1", "idx": 1}],
            []
        ),
        ("/function/nothing", {}, None, []),
        (
            "/function/spawn_inside",
            {"tag": "z"},
            {"tag": "z", "seen": 2},
            [{"inner": True}, {"outer": "z"}]
        )
    ];
    with TemporaryDirectory() as tmpdir {
        client = make_walker_wire_client(tmpdir);
        for (path, body, want_result, want_reports) in cases {
            response = client.post(path, json=body);
            assert response.ok , f"{path} answered {response.status_code}";
            data = response.data;
            got_result = data["result"];
            assert got_result == want_result , (
                f"{path}: result {got_result}, want {want_result}"
            );
            got_reports = data["reports"];
            assert got_reports == want_reports , (
                f"{path}: reports {got_reports}, want {want_reports}"
            );
        }
        client.close();
    }
}
