"""An unknown user is the framework's verdict, never a reading of error text.

The executor reports a caller with no root as a failure that carries its own
401, and one mapping turns every failure into a response. A program whose
exception happens to say "User not found" is therefore an ordinary 500, so a
client that treats 401 as a dead session keeps its token (#9873).
"""
import asyncio;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.runtime.constants { Constants as Con }
import from jaclang.server { sv_client }
import from jaclang.server.server { _abegin_user_request_context }
import from jaclang.testing.testing { JacTestClient }

glob _APP: str = (
         'walker:protect RaisesIt {\n'
         '    can go with Root entry {\n'
         '        raise Exception("User not found");\n'
         '    }\n'
         '}\n'
         '\n'
         'def:protect raises_it -> int {\n'
         '    raise Exception("User not found");\n'
         '}\n'
         '\n'
         'walker:pub Open {\n'
         '    can go with Root entry {\n'
         '        report "open";\n'
         '    }\n'
         '}\n'
     ),
     _TOML: str = (
         '[project]\nname = "unknown_user"\n\n[apps.svc]\nkind = "service"\nentry-point = "app"\n'
     ),
     _ROUTES: list[str] = ["", "/api/svc"];


"""A client on `app.jac`, mounted at the root and at the colocated route."""
def _client(base: str) -> JacTestClient {
    (Path(base) / "jac.toml").write_text(_TOML);
    (Path(base) / "app.jac").write_text(_APP);
    sv_client.set_consumer_app("svc");
    return JacTestClient.from_file(str(Path(base) / "app.jac"), base_path=base);
}


"""A guest account pointing at a root the anchor store has lost, beyond healing."""
obj _GuestWithoutRoot {
    async def aget_root_id(username: str) -> str {
        return "00000000-0000-4000-8000-000000000001";
    }

    def reset_root(username: str) -> None {
        return None;
    }
}


def _error(response: any) -> dict[str, any] {
    return response.json()["error"];
}


test "a program raising the unknown-user text answers 500 and keeps the session" {
    base = tempfile.mkdtemp(prefix="jac_unknown_user_");
    client = _client(base);
    try {
        client.register_user("alice", "secret123");
        for route in _ROUTES {
            for path in (f"{route}/walker/RaisesIt", f"{route}/function/raises_it") {
                response = client.post(path, json={});
                assert response.status_code == 500 , path;
                error = _error(response);
                assert error["code"] == "EXECUTION_ERROR" , path;
                assert error["message"] == "User not found" , path;
            }
        }
    } finally {
        client.close();
        sv_client.set_consumer_app("");
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "a valid token for a user that does not exist answers 401" {
    base = tempfile.mkdtemp(prefix="jac_unknown_user_");
    client = _client(base);
    try {
        client.register_user("alice", "secret123");
        server: any = client._server;
        client.set_auth_token(server.user_manager.create_jwt_token("ghost"));
        for route in _ROUTES {
            for path in (
                f"{route}/walker/RaisesIt",
                f"{route}/function/raises_it",
                f"{route}/walker/Open"
            ) {
                response = client.post(path, json={});
                assert response.status_code == 401 , path;
                assert _error(response)
                    == {
                        "code": "UNAUTHORIZED",
                        "message": "Unauthorized: unknown user"
                    } , path;
            }
        }
    } finally {
        client.close();
        sv_client.set_consumer_app("");
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "a guest whose root cannot be restored is reported with the same failure" {
    base = tempfile.mkdtemp(prefix="jac_unknown_user_");
    client = _client(base);
    try {
        client.register_user("alice", "secret123");
        stub: any = _GuestWithoutRoot();
        server: any = client._server;
        async def begin -> any {
            with server.request_scope() {
                return await _abegin_user_request_context(stub, Con.GUEST.value);
            }
        }
        failure = asyncio.run(begin());
        assert failure
            == {
                "error": "Unauthorized: unknown user",
                "error_code": "unauthorized",
                "http_status": 401
            };
    } finally {
        client.close();
        sv_client.set_consumer_app("");
        shutil.rmtree(base, ignore_errors=True);
    }
}
