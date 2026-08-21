"""
A request that asserts an identity the server cannot resolve is refused.

`request_context_middleware` used to catch the `ValueError` out of
`aset_user_root`, warn, and let the request continue on the execution context's
existing root, which is the system root. The system root returns WRITE for any
anchor and turns the traversal ACL gate off, so the request that landed there
was unauthorized at the tenant boundary. It happened to die a few frames later
on a second, unguarded bind, so the boundary held by redundancy rather than by
decision.

These drive the real path: a real in-process server, a real identity store, a
real register and login, and a real authenticated call. The store is corrupted
through `_update_fields`, the same write the storage layer uses, rather than by
patching anything.
"""

import from jaclang.scale.tests.scale_test_client { make_client }


def _call(client: any, token: str) -> any {
    return client.post(
        "/walker/PublicInfo", json={}, headers={"Authorization": f"Bearer {token}"}
    );
}


test "a stored root id that is not a uuid is refused, not served on the system root" {
    client = make_client("test_api.jac");
    try {
        (user_id, _msg) = client.register_user("rootbind_bad_uuid", "Pass!8348a");
        token = client.login_user("rootbind_bad_uuid", "Pass!8348a");

        control = _call(client, token);
        assert control.status_code == 200 , (
            f"control call failed before the store was touched: "
            f"{control.status_code} {control.text}"
        );

        storage = client._server.user_manager._identity_storage;
        assert storage._update_fields(user_id, {"root_id": "not-a-uuid"}) , (
            "could not write the corrupted root id, so the test proves nothing"
        );

        r = _call(client, token);
        assert r.status_code == 401 , (
            f"a caller whose asserted identity cannot be resolved must be "
            f"refused, not run on the system root: {r.status_code} {r.text}"
        );
        assert r.json().get("error", {}).get("code") == "IDENTITY_UNRESOLVABLE" , (
            f"the refusal must name the condition: {r.json()}"
        );
    } finally {
        client.close();
    }
}


test "a well-formed root id with no anchor behind it is refused the same way" {
    client = make_client("test_api.jac");
    try {
        (user_id, _msg) = client.register_user("rootbind_no_anchor", "Pass!8348b");
        token = client.login_user("rootbind_no_anchor", "Pass!8348b");

        control = _call(client, token);
        assert control.status_code == 200 , (
            f"control call failed before the store was touched: "
            f"{control.status_code} {control.text}"
        );

        storage = client._server.user_manager._identity_storage;
        assert storage._update_fields(
            user_id, {"root_id": "06486588-0000-4000-8000-000000000000"}
        ) , "could not write the unresolvable root id";

        r = _call(client, token);
        assert r.status_code == 401 , (
            f"MissingAnchorError extends ValueError, so this arrived through the "
            f"same swallow and must be refused too: {r.status_code} {r.text}"
        );
    } finally {
        client.close();
    }
}
