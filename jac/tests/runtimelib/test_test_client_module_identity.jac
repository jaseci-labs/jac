"""The test client serves the module its prepared application initialized.

It used to call `initialize_application` and then serve the entry module under
its plain name, which loaded a second copy of every module. Persistence
resolves stored nodes through the application's namespaced modules, so a node
fetched with `jobj()` was an instance of the other copy's class: a walker's
`isinstance(target, Item)` was False and lookup-by-id walkers silently did
nothing under test while working when served for real.
"""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.testing.testing { JacTestClient }

glob FIXTURES = str(Path(__file__).parent / "fixtures");


def _as_any(v: any) -> any {
    return v;
}


test "a node fetched by id is an instance of the walker's own class" {
    with TemporaryDirectory() as tmpdir {
        client = JacTestClient.from_file(
            str((Path(FIXTURES) / "jobj_identity_app.jac").resolve()), base_path=tmpdir
        );
        try {
            assert client.register_user("jobj_a", "pw12345_Secure1").ok;
            made = client.post("/walker/make_item", json={});
            assert made.ok , f"make_item failed: {made.json()}";
            item = _as_any(made.data)["reports"][0];
            item = item[0] if isinstance(item, list) else item;
            found = client.post("/walker/find_item", json={"item_id": item["_jac_id"]});
            assert found.ok , f"find_item failed: {found.json()}";
            assert _as_any(found.data)["reports"][0]["is_item"] , (
                "jobj returned a node of another module copy's class"
            );
        } finally {
            client.close();
        }
    }
}
